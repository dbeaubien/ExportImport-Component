// cs.__ComparePath
//
// DEV ONLY (spec tickets 22 and 21's probe, throw-away). One variant of
// _CompareJob's merge loop, on an exact set's path, over the whole table,
// timed on the loop alone: _range() and the reading of the table's one
// segment come first. Each variant removes steps from the real loop.
// job.variant:
//   - "compare": the loop as _CompareJob._run() has it, with the real _next();
//   - "no_digest": compare without the two Generate digest;
//   - "no_key": compare with each _Codec.key() replaced by reading the
//     Longint key straight from the buffer, with no Base64 and no object;
//   - "no_this": compare with _next() inlined in the loop, and every This
//     read and write in the loop moved to locals; matched is written once;
//   - "lean": no_key and no_this together;
//   - "lean_md5": lean with MD5 in place of SHA-256;
//   - "lean_bytes": lean with no digest: the target's buffer compared with
//     the segment byte by byte, in place, so the source isn't copied;
//   - "lean_nocheck": lean with no comparison of the buffers at all.
// Keys stay Variants in no_key and lean, as a rework's would be. The error
// paths only count a finding (_found()): an exact set never takes them.
// Its row is _CompareJob's, plus ms (the timed loop). Run by
// __Spike_Compare_Path on _WorkerPool.

Class extends _CompareJob

property _key_at : Integer  // the Longint key's offset in a record's buffer, for no_key and lean

Class constructor($job : Object)
	Super($job)
	This._key_at:=0


Function _run()
	var $table : Pointer
	var $segment : Blob
	var $kind; $problem : Text
	var $start : Integer
	For each ($kind; ["records"; "found"; "broke"; "extra_at"; "matched"; "missing"; "extra"; "changed"; "duplicate"; "unverified"])
		This.output.row[$kind]:=0
	End for each
	This._codec:=cs._Codec.new(This.job.table)
	This._key_at:=This._offset()
	READ ONLY(Table(This.job.table.number)->)
	$table:=This._range()
	This.output.row.records:=Records in selection($table->)
	If (This.job.segments.length#1)
		throw({errCode: 99; componentSignature: "ExportImport"; message: "["+This.job.table.name+"] has "+String(This.job.segments.length)+" segments: the probe takes one"})
	End if
	$problem:=This._read(This.job.segments[0]; ->$segment)
	If ($problem#"")
		throw({errCode: 99; componentSignature: "ExportImport"; message: $problem})
	End if

	$start:=Milliseconds
	Case of
		: (This.job.variant="compare")
			This._compare($table; $segment; True)
		: (This.job.variant="no_digest")
			This._compare($table; $segment; False)
		: (This.job.variant="no_key")
			This._no_key($table; $segment)
		: (This.job.variant="no_this")
			This._no_this($table; $segment)
		: (This.job.variant="lean")
			This._lean($table; $segment; 0)
		: (This.job.variant="lean_md5")
			This._lean($table; $segment; 1)
		: (This.job.variant="lean_bytes")
			This._lean($table; $segment; 2)
		Else   // lean_nocheck
			This._lean($table; $segment; 3)
	End case
	This.output.row.ms:=Milliseconds-$start


Function _compare($table : Pointer; $segment : Blob; $digest : Boolean)
	// compare, and no_digest when $digest is False.
	var $source; $target : Blob
	var $sk; $tk : Object
	var $prev : Variant
	var $why : Text
	var $o; $len; $k; $done : Integer
	var $same; $extra : Boolean
	$tk:=This._next($table; ->$target)
	While ($o<BLOB size($segment))
		$len:=BLOB to longint($segment; PC byte ordering; $o)  // moves $o past the length
		$k+=1
		$sk:=This._codec.key(->$segment; $o)
		This._key:=$sk.value
		Case of
			: ($done>0) && Not($prev<$sk.value)
				$why:="order"
			: (This.job.high#Null) && Not($sk.value<This.job.high)
				$why:="high"
		End case
		If ($why#"")
			This.output.row.broke:=1
			break
		End if
		$prev:=$sk.value
		SET BLOB SIZE($source; $len)
		COPY BLOB($segment; $source; $o; 0; $len)

		Repeat
			$same:=($tk#Null) && ($tk.bytes#Null) && (Length($tk.bytes)=Length($sk.bytes)) && (Position($sk.bytes; $tk.bytes; 1; *)=1)
			$extra:=($tk#Null) && Not($same) && ($tk.value<$sk.value)
			If ($extra)
				This._found("extra"; $tk.value)
				$tk:=This._next($table; ->$target)
			End if
		Until (Not($extra))
		Case of
			: ($tk=Null) || (Not($same) && ($sk.value<$tk.value))
				This._found("missing"; $sk.value)
			: ($tk.bytes=Null)
				This._found("unverified"; $tk.value)
				$tk:=This._next($table; ->$target)
			Else
				This.output.row.matched+=1
				If ($digest) && (Generate digest($source; SHA256 digest)#Generate digest($target; SHA256 digest))
					This._found("changed"; $sk.value)
				End if
				$tk:=This._next($table; ->$target)
		End case

		$o+=$len
		$done+=1
		If ($done%1000=0)
			This._tick($done)
		End if
	End while


Function _no_key($table : Pointer; $segment : Blob)
	// no_key: compare, with the keys read straight from the buffers.
	var $source; $target : Blob
	var $sk; $tk; $prev : Variant
	var $why : Text
	var $o; $x; $len; $k; $done : Integer
	var $same; $extra : Boolean
	$tk:=This._next_key($table; ->$target)
	While ($o<BLOB size($segment))
		$len:=BLOB to longint($segment; PC byte ordering; $o)
		$k+=1
		$x:=$o+This._key_at
		$sk:=BLOB to longint($segment; PC byte ordering; $x)
		This._key:=$sk
		Case of
			: ($done>0) && Not($prev<$sk)
				$why:="order"
			: (This.job.high#Null) && Not($sk<This.job.high)
				$why:="high"
		End case
		If ($why#"")
			This.output.row.broke:=1
			break
		End if
		$prev:=$sk
		SET BLOB SIZE($source; $len)
		COPY BLOB($segment; $source; $o; 0; $len)

		Repeat
			$same:=($tk#Null) && ($tk=$sk)
			$extra:=($tk#Null) && Not($same) && ($tk<$sk)
			If ($extra)
				This._found("extra"; $tk)
				$tk:=This._next_key($table; ->$target)
			End if
		Until (Not($extra))
		Case of
			: ($tk=Null) || (Not($same) && ($sk<$tk))
				This._found("missing"; $sk)
			Else
				This.output.row.matched+=1
				If (Generate digest($source; SHA256 digest)#Generate digest($target; SHA256 digest))
					This._found("changed"; $sk)
				End if
				$tk:=This._next_key($table; ->$target)
		End case

		$o+=$len
		$done+=1
		If ($done%1000=0)
			This._tick($done)
		End if
	End while


Function _next_key($table : Pointer; $buffer : Pointer) : Variant
	// no_key's _next(): the next target record that can match, encoded into
	// $buffer, as its key read straight from the buffer, or Null past the end.
	var $value : Variant
	var $x : Integer
	While (This._t<Records in selection($table->))
		This._t+=1
		Try
			GOTO SELECTED RECORD($table->; This._t)
			$buffer->:=This._codec.encode()
			$x:=This._key_at
			$value:=BLOB to longint($buffer->; PC byte ordering; $x)
		Catch
			$value:=Null
		End try
		This._key:=$value
		Case of
			: ($value=Null)
				This._found("unverified"; Null)
			: (Value type($value)=Is text) && (Position("@"; $value; 1; *)>0)
				This._found("extra"; $value)
			: (This._last#Null) && ($value=This._last)
				This._found("duplicate"; $value)
			Else
				This._last:=$value
				This._in_group:=False
				return $value
		End case
	End while
	return Null


Function _no_this($table : Pointer; $segment : Blob)
	// no_this: compare with _next() inlined, run when $need is set, and its
	// state and the job's in locals.
	var $codec : cs._Codec
	var $source; $target : Blob
	var $sk; $tk : Object
	var $prev; $high; $key; $last : Variant
	var $why : Text
	var $o; $len; $k; $done; $t; $matched : Integer
	var $same; $extra; $need; $in_group : Boolean
	$codec:=This._codec
	$high:=This.job.high
	$last:=Null
	$need:=True
	While ($o<BLOB size($segment))
		$len:=BLOB to longint($segment; PC byte ordering; $o)
		$k+=1
		$sk:=$codec.key(->$segment; $o)
		$key:=$sk.value
		Case of
			: ($done>0) && Not($prev<$sk.value)
				$why:="order"
			: ($high#Null) && Not($sk.value<$high)
				$why:="high"
		End case
		If ($why#"")
			This.output.row.broke:=1
			break
		End if
		$prev:=$sk.value
		SET BLOB SIZE($source; $len)
		COPY BLOB($segment; $source; $o; 0; $len)

		Repeat
			While ($need)  // _next(), inlined
				If ($t>=Records in selection($table->))
					$tk:=Null
					$need:=False
				Else
					$t+=1
					Try
						GOTO SELECTED RECORD($table->; $t)
						$target:=$codec.encode()
						$tk:=$codec.key(->$target; 0)
					Catch
						$tk:={bytes: Null; value: Null}
					End try
					$key:=$tk.value
					Case of
						: ($tk.value=Null)
							This._found("unverified"; Null)
						: (Value type($tk.value)=Is text) && (Position("@"; $tk.value; 1; *)>0)
							This._found("extra"; $tk.value)
						: ($last#Null) && ($tk.value=$last)
							This._found("duplicate"; $tk.value)
						Else
							$last:=$tk.value
							$in_group:=False
							$need:=False
					End case
				End if
			End while
			$same:=($tk#Null) && ($tk.bytes#Null) && (Length($tk.bytes)=Length($sk.bytes)) && (Position($sk.bytes; $tk.bytes; 1; *)=1)
			$extra:=($tk#Null) && Not($same) && ($tk.value<$sk.value)
			If ($extra)
				This._found("extra"; $tk.value)
				$need:=True
			End if
		Until (Not($extra))
		Case of
			: ($tk=Null) || (Not($same) && ($sk.value<$tk.value))
				This._found("missing"; $sk.value)
			: ($tk.bytes=Null)
				This._found("unverified"; $tk.value)
				$need:=True
			Else
				$matched+=1
				If (Generate digest($source; SHA256 digest)#Generate digest($target; SHA256 digest))
					This._found("changed"; $sk.value)
				End if
				$need:=True
		End case

		$o+=$len
		$done+=1
		If ($done%1000=0)
			This._tick($done)
		End if
	End while
	This.output.row.matched:=$matched


Function _lean($table : Pointer; $segment : Blob; $check : Integer)
	// lean: no_this with the keys read straight from the buffers, as no_key.
	// $check compares a matched pair's buffers: 0 SHA-256, 1 MD5, 2 byte by
	// byte against the segment (the source isn't copied), 3 not at all.
	var $codec : cs._Codec
	var $source; $target : Blob
	var $sk; $tk; $prev; $high; $key; $last : Variant
	var $why : Text
	var $o; $x; $at; $len; $k; $done; $t; $matched; $i : Integer
	var $same; $extra; $need; $end; $in_group; $differ : Boolean
	$codec:=This._codec
	$high:=This.job.high
	$at:=This._key_at
	$last:=Null
	$need:=True
	While ($o<BLOB size($segment))
		$len:=BLOB to longint($segment; PC byte ordering; $o)
		$k+=1
		$x:=$o+$at
		$sk:=BLOB to longint($segment; PC byte ordering; $x)
		$key:=$sk
		Case of
			: ($done>0) && Not($prev<$sk)
				$why:="order"
			: ($high#Null) && Not($sk<$high)
				$why:="high"
		End case
		If ($why#"")
			This.output.row.broke:=1
			break
		End if
		$prev:=$sk
		If ($check<2)  // a digest needs the source record in its own buffer
			SET BLOB SIZE($source; $len)
			COPY BLOB($segment; $source; $o; 0; $len)
		End if

		Repeat
			While ($need)  // _next(), inlined
				If ($t>=Records in selection($table->))
					$end:=True
					$need:=False
				Else
					$t+=1
					Try
						GOTO SELECTED RECORD($table->; $t)
						$target:=$codec.encode()
						$x:=$at
						$tk:=BLOB to longint($target; PC byte ordering; $x)
					Catch
						$tk:=Null
					End try
					$key:=$tk
					Case of
						: ($tk=Null)
							This._found("unverified"; Null)
						: (Value type($tk)=Is text) && (Position("@"; $tk; 1; *)>0)
							This._found("extra"; $tk)
						: ($last#Null) && ($tk=$last)
							This._found("duplicate"; $tk)
						Else
							$last:=$tk
							$in_group:=False
							$need:=False
					End case
				End if
			End while
			$same:=Not($end) && ($tk=$sk)
			$extra:=Not($end) && Not($same) && ($tk<$sk)
			If ($extra)
				This._found("extra"; $tk)
				$need:=True
			End if
		Until (Not($extra))
		Case of
			: ($end) || (Not($same) && ($sk<$tk))
				This._found("missing"; $sk)
			Else
				$matched+=1
				Case of
					: ($check=0)
						$differ:=(Generate digest($source; SHA256 digest)#Generate digest($target; SHA256 digest))
					: ($check=1)
						$differ:=(Generate digest($source; MD5 digest)#Generate digest($target; MD5 digest))
					: ($check=2)  // the record's bytes start at $o in the segment
						$differ:=(BLOB size($target)#$len)
						$i:=0
						While (Not($differ)) && ($i<$len)
							$differ:=($segment{$o+$i}#$target{$i})
							$i+=1
						End while
					Else
						$differ:=False
				End case
				If ($differ)
					This._found("changed"; $sk)
				End if
				$need:=True
		End case

		$o+=$len
		$done+=1
		If ($done%1000=0)
			This._tick($done)
		End if
	End while
	This.output.row.matched:=$matched


Function _offset() : Integer
	// The record key's offset in a buffer: the widths of the fixed-width
	// fields before it. A Longint key only.
	var $i; $o : Integer
	For ($i; 0; This._codec._key-1)
		If (This._codec._fields[$i].width=0)
			throw({errCode: 99; componentSignature: "ExportImport"; message: "["+This.job.table.name+"]: a variable-width field before the key"})
		End if
		$o+=This._codec._fields[$i].width
	End for
	If (This._codec._key<0) || (This._codec._fields[This._codec._key].kind#Is longint)
		throw({errCode: 99; componentSignature: "ExportImport"; message: "["+This.job.table.name+"]: the probe takes a Longint key"})
	End if
	return $o
