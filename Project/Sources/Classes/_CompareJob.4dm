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
property _t : Integer  // the position of the target record in hand, in the selection
property _last : Variant  // the key of the last target record that could match, for duplicates; Null at first
property _group : Object  // the duplicate finding of _last, or Null when it isn't listed
property _in_group : Boolean  // _last is held by more than one record
property _listed : Integer  // the findings listed, ranges aside

Class constructor($job : Object)
	Super($job)
	This._t:=0
	This._last:=Null
	This._group:=Null
	This._in_group:=False
	This._listed:=0


Function _run()
	var $table : Pointer
	var $segment; $source; $target : Blob
	var $s; $sk; $tk : Object
	var $prev : Variant
	var $kind; $why; $problem : Text
	var $o; $len; $k; $done; $n : Integer
	var $same; $extra : Boolean
	For each ($kind; ["records"; "found"; "broke"; "extra_at"; "matched"; "missing"; "extra"; "changed"; "duplicate"; "unverified"])
		This.output.row[$kind]:=0
	End for each
	This._codec:=cs._Codec.new(This.job.table)
	READ ONLY(Table(This.job.table.number)->)
	$table:=This._range()
	This.output.row.records:=Records in selection($table->)  // for the pool's log line: the pass removes it
	$tk:=This._next($table; ->$target)

	For each ($s; This.job.segments) Until ($why#"")
		This._tick($done)
		$problem:=This._read($s; ->$segment)
		If ($problem#"")  // damaged: the target records before its keys are extra, and those in them unverified
			While ($tk#Null) && ($tk.value<$s.first_key)
				This._found("extra"; $tk.value)
				$tk:=This._next($table; ->$target)
			End while
			$n:=This.output.row.unverified
			$tk:=This._unverified($table; ->$target; $tk; $s.last_key; $problem)
			This._unverified_range($s.first_key; $s.last_key; True; $s.records; This.output.row.unverified-$n; $problem)
			$prev:=$s.last_key
			$done+=$s.records
		Else
			$o:=0
			$k:=0
			While ($o<BLOB size($segment))
				$len:=BLOB to longint($segment; PC byte ordering; $o)  // moves $o past the length
				$k+=1
				$sk:=This._codec.key(->$segment; $o)
				This._key:=$sk.value
				Case of
					: ($done>0) && Not($prev<$sk.value)
						$why:="isn't after the key before it, "+JSON Stringify($prev)
					: (This.job.high#Null) && Not($sk.value<This.job.high)
						$why:="isn't before the next job's first key, "+JSON Stringify(This.job.high)
				End case
				If ($why#"")
					$why:="the source key "+JSON Stringify($sk.value)+" "+$why+", in this datafile's order: the two datafiles order keys differently"
					break
				End if
				$prev:=$sk.value
				SET BLOB SIZE($source; $len)
				COPY BLOB($segment; $source; $o; 0; $len)

				Repeat   // the target records before this key are extra
					$same:=($tk#Null) && ($tk.bytes#Null) && (Length($tk.bytes)=Length($sk.bytes)) && (Position($sk.bytes; $tk.bytes; 1; *)=1)
					$extra:=($tk#Null) && Not($same) && ($tk.value<$sk.value)
					If ($extra)
						This._found("extra"; $tk.value)
						$tk:=This._next($table; ->$target)
					End if
				Until (Not($extra))
				Case of
					: ($tk=Null) || (Not($same) && ($sk.value<$tk.value))
						This._found("missing"; $sk.value; {segment: $s.file; position: $k})
					: ($tk.bytes=Null)  // the same key, but the target record can't be read
						This._found("unverified"; $tk.value; {reason: $tk.reason})
						$tk:=This._next($table; ->$target)
					Else   // the same key: equal bytes, or equal in the target's order
						This.output.row.matched+=1
						If (Generate digest($source; SHA256 digest)#Generate digest($target; SHA256 digest))
							This._found("changed"; $sk.value; {fields: This._fields(->$source; ->$target)})
						End if
						$tk:=This._next($table; ->$target)
				End case

				$o+=$len
				$done+=1
				If ($done%1000=0)
					This._tick($done)
				End if
			End while
		End if
	End for each

	If ($why#"")  // the order guard broke: from the last good key to the end of the job's range
		This.output.row.broke:=1
		$n:=This.output.row.unverified
		$tk:=This._unverified($table; ->$target; $tk; Null; $why)
		This._unverified_range($prev; This.job.high; False; This.job.expected-$done; This.output.row.unverified-$n; $why)
	End if
	While ($tk#Null)  // the target records past the last source key
		This._found("extra"; $tk.value)
		$tk:=This._next($table; ->$target)
	End while


Function _next($table : Pointer; $buffer : Pointer) : Object
	// The next target record that can match, encoded into $buffer: its key
	// {bytes; value}, or Null past the end. One that can't be loaded or
	// encoded gives {bytes: Null; value; reason}, value read from its key
	// field, or Null when the record didn't load. On the way, a record whose
	// key can't be read is unverified, one whose key contains @ is extra, and
	// one whose key equals the one before is a duplicate.
	var $key : Object
	While (This._t<Records in selection($table->))
		This._t+=1
		Try
			GOTO SELECTED RECORD($table->; This._t)
			$buffer->:=This._codec.encode()
			$key:=This._codec.key($buffer; 0)
		Catch
			$key:={bytes: Null; value: Null; reason: "the record can't be read: "+Last errors.first().message}
			If (Selected record number($table->)=This._t)  // it loaded: its key can be read
				$key.value:=Field(This.job.table.number; This.job.table.primary_key)->
			End if
		End try
		This._key:=$key.value
		Case of
			: ($key.value=Null)
				This._found("unverified"; Null; {reason: $key.reason})
			: (Value type($key.value)=Is text) && (Position("@"; $key.value; 1; *)>0)
				This._found("extra"; $key.value)
				This.output.row.extra_at+=1
			: (This._last#Null) && ($key.value=This._last)
				If (This._in_group)
					This.output.row.duplicate+=1
					If (This._group#Null)
						This._group.records+=1
					End if
				Else
					This._group:=This._found("duplicate"; $key.value; {records: 2})
					This._in_group:=True
				End if
			Else
				This._last:=$key.value
				This._in_group:=False
				return $key
		End case
	End while
	return Null


Function _unverified($table : Pointer; $buffer : Pointer; $tk : Object; $to : Variant; $reason : Text) : Object
	// The target records from $tk up to $to, inclusive, are unverified (Null:
	// to the end of the job's range). Returns the target record after them.
	While ($tk#Null) && (($to=Null) || Not($to<$tk.value))
		This._found("unverified"; $tk.value; {reason: $reason})
		$tk:=This._next($table; $buffer)
	End while
	return $tk


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
