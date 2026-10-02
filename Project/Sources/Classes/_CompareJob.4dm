// cs._CompareJob
//
// Compare (specs 08 and 10) of one run of a table's segments against this
// datafile, as a job. It reads the target's records in the job's key range
// in key order, and streams the run's segments in position order beside
// them, checking each segment's size, SHA-256 and record count as it reads
// it. A lockstep merge on the record key, each target record encoded with
// _Codec:
//   - keys whose bytes are equal match, and a pair whose buffers' SHA-256
//     differ is changed, sliced by field to name each field that differs,
//     with its two values as the report shows them (_values());
//   - otherwise the target's < decides missing or extra, and keys it finds
//     equal match, changed in the key field;
//   - a target key equal to the one before it is a duplicate, and one that
//     contains @ is extra on sight (spec 14): it never enters <, = or the
//     duplicate check.
// The order guard: each source key must be above the one before it and
// below the job's high, under the target's <. No source key contains @,
// which < reads as a wildcard in its right operand: the export refuses one.
// The per-record path (spec 21) keeps its state in locals, and reads each
// key straight from its buffer: its bytes in place for equality, and its
// value, as _Codec reads it, for order.
//
// Unverified records, never a discrepancy (spec 08, narrowed by spec 10):
//   - a damaged segment (missing, or its size, SHA-256 or record count isn't
//     the manifest's): the target records from its first_key to its
//     last_key, inclusive. Those before it are extra, as usual;
//   - an order guard break: the target records from the last good key to
//     the end of the job's range, and the merge stops there;
//   - a target record that can't be loaded or encoded: its key only, when a
//     source record has it. Without one, it is extra.
//
// Adds to the job contract folder, the platform path of the table's folder
// in the set, and detail_limit. Its row adds matched (changed included),
// missing, extra, changed, duplicate (each target record past a key's
// first), unverified (target records), and for the pass, which removes
// them: found (the discrepancies listed or not, for "N more not listed"),
// broke (1 when the order guard broke) and extra_at (the extras whose key
// contains @, spec 16). Its findings, in key order:
//   - one per discrepancy and one per unverified target record, at most
//     detail_limit per job of the two together: {table; kind; key}, plus
//     segment and position (missing: the record's place in its segment,
//     from 1), fields (changed: [{number; name; source; target; …}]),
//     records (duplicate: the records that hold the key) and reason
//     (unverified);
//   - one per unverified range, always: {table; kind: "range"; from; to;
//     inclusive (else both ends are left out, and Null is an open end);
//     source_records (the manifest's); target_records; reason}.

Class extends _Job

property _codec : cs._Codec
property _listed : Integer  // the findings listed, ranges aside

Class constructor($job : Object)
	Super($job)
	This._listed:=0


Function _run()
	// One loop of probes: each source record, each damaged segment, then the
	// end of the job. Before each, the target records below it are taken,
	// as extra or unverified, and the next one is fetched only when needed.
	var $table : Pointer
	var $codec : cs._Codec
	var $segment; $source; $target : Blob
	var $s; $group : Object
	var $widths : Collection
	var $sk; $tk; $prev; $high; $last : Variant
	var $kind; $why; $problem; $treason : Text
	var $probe; $take; $i; $size; $o; $x; $len; $k; $done; $n; $t; $count; $matched; $key; $kw; $at; $ks; $kt; $ssize; $tsize; $f; $b : Integer
	var $need; $end; $unread; $same; $in_group; $damaged : Boolean
	For each ($kind; ["records"; "found"; "broke"; "extra_at"; "matched"; "missing"; "extra"; "changed"; "duplicate"; "unverified"])
		This.output.row[$kind]:=0
	End for each
	This._codec:=cs._Codec.new(This.job.table)
	$codec:=This._codec
	$key:=$codec._key  // the record key's index in a buffer's fields
	$widths:=$codec._fields.extract("width")  // 0: variable width, behind a 4-byte length
	$kw:=($key<0) ? 0 : $widths[$key]  // no key: only an empty table passes the gate
	$at:=0  // the key's offset in a buffer when only fixed-width fields come before it, else -1
	For ($f; 0; $key-1)
		$at:=(($at<0) || ($widths[$f]=0)) ? -1 : ($at+$widths[$f])
	End for
	$high:=This.job.high
	$last:=Null  // the key of the last target record that could match, for duplicates
	READ ONLY(Table(This.job.table.number)->)
	$table:=This._range()
	$count:=Records in selection($table->)
	This.output.row.records:=$count  // for the pool's log line: the pass removes it
	$need:=True

	Repeat
		While (Not($damaged)) && ($o>=$size) && ($i<This.job.segments.length)  // the next segment
			$s:=This.job.segments[$i]
			$i+=1
			This._tick($done)
			$problem:=This._read($s; ->$segment)
			$damaged:=($problem#"")
			$o:=0
			$k:=0
			$size:=$damaged ? 0 : BLOB size($segment)
		End while
		Case of
			: ($damaged)
				$probe:=1  // a damaged segment: the target records before its keys are extra, and those in them unverified
			: ($o<$size)
				$probe:=0  // the next source record
			Else
				$probe:=2  // the end of the job: the target records left
		End case

		If ($probe=0)  // its key, and the order guard
			$len:=BLOB to longint($segment; PC byte ordering; $o)  // moves $o past the length
			$k+=1
			$ks:=$o+$at
			If ($at<0)  // walk the fields before the key
				$ks:=$o
				For ($f; 0; $key-1)
					$x:=$ks
					$ks+=($widths[$f]>0) ? $widths[$f] : (4+BLOB to longint($segment; PC byte ordering; $x))
				End for
			End if
			$x:=$ks
			$ssize:=$kw
			Case of
				: ($kw=0)  // Alpha, Text, UUID
					$ssize:=4+BLOB to longint($segment; PC byte ordering; $x)  // moves $x to the text
					$sk:=$codec._text(->$segment; $x; $ssize-4)
				: ($kw=8)
					$sk:=BLOB to real($segment; PC double real format; $x)
				Else
					$sk:=BLOB to longint($segment; PC byte ordering; $x)
			End case
			This._key:=$sk
			Case of
				: ($done>0) && Not($prev<$sk)
					$why:="isn't after the key before it, "+JSON Stringify($prev)
					$probe:=2
				: ($high#Null) && Not($sk<$high)
					$why:="isn't before the next job's first key, "+JSON Stringify($high)
					$probe:=2
				Else
					$prev:=$sk
			End case
			If ($probe=2)  // the order guard broke: from the last good key to the end of the job's range
				$why:="the source key "+JSON Stringify($sk)+" "+$why+", in this datafile's order: the two datafiles order keys differently"
			End if
		End if

		$n:=-1
		Repeat   // the target records before it
			While ($need)  // the next target record that can match
				If ($t>=$count)
					$end:=True
					$need:=False
				Else
					$t+=1
					$unread:=False
					Try
						GOTO SELECTED RECORD($table->; $t)
						$target:=$codec.encode()
						$kt:=$at
						If ($at<0)
							$kt:=0
							For ($f; 0; $key-1)
								$x:=$kt
								$kt+=($widths[$f]>0) ? $widths[$f] : (4+BLOB to longint($target; PC byte ordering; $x))
							End for
						End if
						$x:=$kt
						$tsize:=$widths[$key]  // not $kw: with no key, this throws, as key() did
						Case of
							: ($kw=0)
								$tsize:=4+BLOB to longint($target; PC byte ordering; $x)
								$tk:=$codec._text(->$target; $x; $tsize-4)
							: ($kw=8)
								$tk:=BLOB to real($target; PC double real format; $x)
							Else
								$tk:=BLOB to longint($target; PC byte ordering; $x)
						End case
					Catch
						$unread:=True
						$treason:="the record can't be read: "+Last errors.first().message
						$tk:=Null
						If (Selected record number($table->)=$t)  // it loaded: its key can be read
							$tk:={v: Field(This.job.table.number; This.job.table.primary_key)->}.v  // through an object, as before: a time reads as seconds
						End if
					End try
					Case of
						: ($tk=Null)
							This._found("unverified"; Null; {reason: $treason})
						: (Value type($tk)=Is text) && (Position("@"; $tk; 1; *)>0)
							This._found("extra"; $tk)
							This.output.row.extra_at+=1
						: ($last#Null) && ($tk=$last)
							If ($in_group)
								This.output.row.duplicate+=1
								If ($group#Null)
									$group.records+=1
								End if
							Else
								$group:=This._found("duplicate"; $tk; {records: 2})
								$in_group:=True
							End if
						Else
							$last:=$tk
							$in_group:=False
							$need:=False
					End case
				End if
			End while

			$take:=0  // 0: stop here, 1: extra, 2: unverified
			Case of
				: ($probe=0)
					$same:=Not($end) && Not($unread) && ($tsize=$ssize)
					$b:=0
					While ($same) && ($b<$ssize)  // the two keys' bytes, in place
						$same:=($segment{$ks+$b}=$target{$kt+$b})
						$b+=1
					End while
					If (Not($end) && Not($same) && ($tk<$sk))
						$take:=1
					End if
				: ($end)
				: ($probe=1)
					Case of
						: ($tk<$s.first_key)
							$take:=1
						: (Not($s.last_key<$tk))
							$take:=2
					End case
				Else
					$take:=($why="") ? 1 : 2
			End case
			If ($probe>0) && ($take#1) && ($n<0)  // a range counts its target records from the first that isn't extra
				$n:=This.output.row.unverified
			End if
			Case of
				: ($take=1)
					This._found("extra"; $tk)
					$need:=True
				: ($take=2)
					This._found("unverified"; $tk; {reason: ($probe=1) ? $problem : $why})
					$need:=True
			End case
		Until ($take=0)

		Case of
			: ($probe=0)
				Case of
					: ($end) || (Not($same) && ($sk<$tk))
						This._found("missing"; $sk; {segment: $s.file; position: $k})
					: ($unread)  // the same key, but the target record can't be read
						This._found("unverified"; $tk; {reason: $treason})
						$need:=True
					Else   // the same key: equal bytes, or equal in the target's order
						$matched+=1
						SET BLOB SIZE($source; $len)
						COPY BLOB($segment; $source; $o; 0; $len)
						If (Generate digest($source; SHA256 digest)#Generate digest($target; SHA256 digest))
							This._found("changed"; $sk; {fields: This._fields(->$source; ->$target)})
						End if
						$need:=True
				End case
				$o+=$len
				$done+=1
				If ($done%1000=0)
					This._tick($done)
				End if
			: ($probe=1)
				This._unverified_range($s.first_key; $s.last_key; True; $s.records; This.output.row.unverified-$n; $problem)
				$prev:=$s.last_key
				$done+=$s.records
				$damaged:=False
			: ($why#"")
				This.output.row.broke:=1
				This._unverified_range($prev; $high; False; This.job.expected-$done; This.output.row.unverified-$n; $why)
		End case
	Until ($probe=2)
	This.output.row.matched:=$matched


Function _unverified_range($from : Variant; $to : Variant; $inclusive : Boolean; $source : Integer; $target : Integer; $reason : Text)
	// An unverified range: always listed.
	This.output.findings.push({table: This.job.table.name; kind: "range"; from: $from; to: $to; inclusive: $inclusive; source_records: $source; target_records: $target; reason: $reason})


Function _read($s : Object; $segment : Pointer) : Text
	// Reads the segment into $segment, checked against the manifest: its
	// size, its SHA-256 and its record count. Returns "", or what is wrong.
	var $file : 4D.File
	var $problem : Text
	var $o; $len; $n : Integer
	$file:=Folder(This.job.folder; fk platform path).file($s.file)
	If (Not($file.exists))
		return "the segment "+$s.file+" is missing"
	End if
	$segment->:=$file.getContent()
	Case of
		: (BLOB size($segment->)#$s.bytes)
			$problem:="has "+String(BLOB size($segment->))+" bytes, not "+String($s.bytes)
		: (Generate digest($segment->; SHA256 digest)#$s.sha256)
			$problem:="doesn't match its SHA-256"
		Else   // its records' lengths must add up to its size
			While (($o+4)<=BLOB size($segment->)) && ($n<$s.records)
				$len:=BLOB to longint($segment->; PC byte ordering; $o)
				If ($len<0) || ($len>(BLOB size($segment->)-$o))
					break
				End if
				$o+=$len
				$n+=1
			End while
			If ($o#BLOB size($segment->)) || ($n#$s.records)
				$problem:="doesn't decode into its "+String($s.records)+" records"
			End if
	End case
	return ($problem="") ? "" : ("the segment "+$s.file+" "+$problem)


Function _fields($source : Pointer; $target : Pointer) : Collection
	// The fields whose slices differ between the two buffers, in field order:
	// [{number; name; source; target; …}], see _values().
	var $a; $b : Blob
	var $s; $t; $fields : Collection
	var $field : Object
	var $i : Integer
	$s:=This._codec.slices($source; 0)
	$t:=This._codec.slices($target; 0)
	$fields:=[]
	For ($i; 0; $s.length-1)
		SET BLOB SIZE($a; $s[$i].size)
		COPY BLOB($source->; $a; $s[$i].start; 0; $s[$i].size)
		SET BLOB SIZE($b; $t[$i].size)
		COPY BLOB($target->; $b; $t[$i].start; 0; $t[$i].size)
		If (Generate digest($a; SHA256 digest)#Generate digest($b; SHA256 digest))
			$field:=This.job.table.fields[$i]
			$fields.push(This._values({number: $field.number; name: $field.name}; This._codec.readable($source; $s[$i].start; $i); This._codec.readable($target; $t[$i].start; $i); ->$a; ->$b))
		End if
	End for
	return $fields


Function _values($field : Object; $source : Variant; $target : Variant; $a : Pointer; $b : Pointer) : Object
	// Adds a changed field's two values to $field, as _Codec.readable() gives
	// them (spec 08). A text is capped at 1,000 characters, with both lengths
	// and first_difference, the first character that differs, from 1. When
	// both read the same (-0 and +0, or texts that 4D's strict comparison
	// finds equal), source_hex and target_hex hold the slices $a and $b in
	// hex too, capped at 1,000 bytes.
	var $x; $y : Text
	var $same : Boolean
	var $i; $n : Integer
	If (Value type($source)=Is text)
		$x:=$source
		$y:=$target
		$field.source:=Substring($x; 1; 1000)
		$field.target:=Substring($y; 1; 1000)
		$field.source_length:=Length($x)
		$field.target_length:=Length($y)
		$n:=(Length($x)<Length($y)) ? Length($x) : Length($y)
		$i:=1
		While ($i<=$n) && (Character code($x[[$i]])=Character code($y[[$i]]))
			$i+=1
		End while
		$field.first_difference:=$i
		$same:=(Compare strings($x; $y; sk strict)=0)
	Else
		$field.source:=$source
		$field.target:=$target
		$same:=(Value type($source)=Is real) ? ($source=$target) : (JSON Stringify($source)=JSON Stringify($target))
	End if
	If ($same)
		$field.source_hex:=This._hex($a)
		$field.target_hex:=This._hex($b)
	End if
	return $field


Function _hex($slice : Pointer) : Text
	// The slice's first 1,000 bytes in hex.
	var $hex : Text
	var $i : Integer
	For ($i; 0; ((BLOB size($slice->)<1000) ? BLOB size($slice->) : 1000)-1)
		$hex+=Substring("0123456789abcdef"; ($slice->{$i}\16)+1; 1)+Substring("0123456789abcdef"; ($slice->{$i}%16)+1; 1)
	End for
	return $hex


Function _found($kind : Text; $key : Variant; $detail : Object) : Object
	// Counts a discrepancy, or an unverified target record, on the row, and
	// lists it within detail_limit per job: {table; kind; key}, plus
	// $detail's keys. Returns it, or Null.
	var $finding : Object
	var $name : Text
	This.output.row[$kind]:=This.output.row[$kind]+1
	If ($kind#"unverified")
		This.output.row.found+=1
	End if
	If (This._listed>=This.job.detail_limit)
		return Null
	End if
	This._listed+=1
	$finding:={table: This.job.table.name; kind: $kind; key: $key}
	If ($detail#Null)
		For each ($name; $detail)
			$finding[$name]:=$detail[$name]
		End for each
	End if
	This.output.findings.push($finding)
	return $finding
