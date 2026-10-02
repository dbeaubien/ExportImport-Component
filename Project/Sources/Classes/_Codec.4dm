// cs._Codec
//
// One table's record codec (spec 04): the current record to its canonical
// buffer and back. Built once per table from its entry in a _Structure list
// or a manifest ({number; name; primary_key; fields}). Runs in preemptive
// workers, so it calls only thread-safe commands.
//
// A buffer holds the fields in field-number order. Fixed-width values go in
// raw and little-endian. Variable-width values (Alpha, Text, UUID, BLOB,
// picture, object) go behind a 4-byte little-endian length. Each value is
// read as the language reads it, so null is encoded as blank. A null or {}
// object, and a "" or all-zero UUID, are encoded as empty.
// The functions that read a buffer take a pointer to it and the record's
// offset, so a segment is never copied.
//
// Errors thrown (errCode, componentSignature "ExportImport"):
//   1 the buffer would pass 2 GB, 2 an Int64 value beyond ±2^53 (2^53+1 reads
//   as 2^53, so only the gate's engine query sees that one), 3 a lone surrogate
//   in an Alpha or Text value (UTF-8 can't hold it, ticket 01's fact 3), 4 a
//   field type that can't be encoded (Float, subtable).

property table : Text  // the table's name, for errors
property _fields : Collection  // per field: {name; ptr; kind; width (0 = variable); uuid}
property _key : Integer  // the record key's index in _fields, -1 if none
property _key_ptr : Pointer

Class constructor($table : Object)
	var $field : Object
	var $kind; $width : Integer
	This.table:=$table.name
	This._fields:=[]
	This._key:=-1
	For each ($field; $table.fields)
		$width:=0
		Case of
			: ($field.type="BOOL")
				$kind:=Is boolean
				$width:=1
			: ($field.type="I16") | ($field.type="I32")
				$kind:=Is longint
				$width:=4
			: ($field.type="I64")
				$kind:=Is integer 64 bits
				$width:=8
			: ($field.type="REAL")
				$kind:=Is real
				$width:=8
			: ($field.type="DATE")
				$kind:=Is date
				$width:=4
			: ($field.type="TIME")
				$kind:=Is time
				$width:=8
			: ($field.type="STR") | ($field.type="TEXT") | ($field.type="UUID")
				$kind:=Is text
			: ($field.type="BLOB")
				$kind:=Is BLOB
			: ($field.type="PICT")
				$kind:=Is picture
			: ($field.type="OBJ")
				$kind:=Is object
			Else
				throw({errCode: 4; componentSignature: "ExportImport"; message: "["+$table.name+"]"+$field.name+": a field of type "+$field.type+" can't be encoded"})
		End case
		If ($field.number=$table.primary_key)
			This._key:=This._fields.length
			This._key_ptr:=Field($table.number; $field.number)
		End if
		This._fields.push({name: $field.name; ptr: Field($table.number; $field.number); kind: $kind; width: $width; uuid: ($field.type="UUID")})
	End for each


Function encode() : Blob
	// The current record's canonical buffer.
	var $buffer; $bytes : Blob
	var $f : Object
	var $p : Pointer
	var $o : Integer
	var $r : Real
	var $d : Date
	var $t : Text
	var $pic : Picture
	var $obj : Object
	For each ($f; This._fields)
		$p:=$f.ptr
		If ($f.width>0)
			Case of
				: ($f.kind=Is boolean)
					SET BLOB SIZE($buffer; $o+1)
					$buffer{$o}:=Num($p->)
					$o+=1
				: ($f.kind=Is longint)
					LONGINT TO BLOB($p->; $buffer; PC byte ordering; $o)
				: ($f.kind=Is date)  // yyyymmdd, blank = 0
					$d:=$p->
					LONGINT TO BLOB((Year of($d)*10000)+(Month of($d)*100)+Day of($d); $buffer; PC byte ordering; $o)
				: ($f.kind=Is time)  // seconds
					REAL TO BLOB($p->+0; $buffer; PC double real format; $o)
				Else   // Real, and Int64, which the language reads as a Real
					$r:=$p->
					If ($f.kind=Is integer 64 bits) && (Abs($r)>(2^53))
						This._fail(2; $f.name+": the Int64 value "+String($r)+" is beyond ±2^53")
					End if
					REAL TO BLOB($r; $buffer; PC double real format; $o)
			End case
		Else
			SET BLOB SIZE($bytes; 0)
			Case of
				: ($f.uuid)
					$t:=$p->
					If ($t#"") && ($t#"00000000000000000000000000000000")
						CONVERT FROM TEXT($t; "UTF-8"; $bytes)
					End if
				: ($f.kind=Is text)
					$t:=$p->
					If (Match regex("[\\x{D800}-\\x{DFFF}]"; $t; 1))  // a pair is one code point, so only a lone surrogate matches
						This._fail(3; $f.name+": a lone surrogate, which UTF-8 can't hold")
					End if
					CONVERT FROM TEXT($t; "UTF-8"; $bytes)
				: ($f.kind=Is BLOB)
					$bytes:=$p->
				: ($f.kind=Is picture)
					$pic:=$p->
					VARIABLE TO BLOB($pic; $bytes)
				Else   // Object
					$obj:=$p->
					If (Not(OB Is empty($obj)))
						VARIABLE TO BLOB($obj; $bytes)
					End if
			End case
			If (BLOB size($bytes)>(MAXLONG-4-$o))  // written so that it can't overflow
				This._fail(1; "the buffer would pass the 2 GB limit at field "+$f.name)
			End if
			LONGINT TO BLOB(BLOB size($bytes); $buffer; PC byte ordering; $o)
			SET BLOB SIZE($buffer; $o+BLOB size($bytes))
			COPY BLOB($bytes; $buffer; 0; $o; BLOB size($bytes))
			$o+=BLOB size($bytes)
		End if
	End for each
	return $buffer


Function decode($buffer : Pointer; $offset : Integer)
	// Assigns every field of the current record from the buffer at offset.
	// An empty UUID is written as the all-zero UUID: never "", which stores
	// 0x20 bytes, and never null, which loading an Auto UUID field would fill.
	var $bytes : Blob
	var $f : Object
	var $p : Pointer
	var $o; $at; $size; $n : Integer
	var $t : Text
	var $pic : Picture
	var $obj : Object
	$o:=$offset
	For each ($f; This._fields)
		$p:=$f.ptr
		Case of
			: ($f.kind=Is boolean)
				$p->:=($buffer->{$o}=1)
				$o+=1
			: ($f.kind=Is longint)
				$p->:=BLOB to longint($buffer->; PC byte ordering; $o)
			: ($f.kind=Is date)
				$n:=BLOB to longint($buffer->; PC byte ordering; $o)
				$p->:=Add to date(!00-00-00!; $n\10000; ($n\100)%100; $n%100)
			: ($f.kind=Is time)
				$p->:=Time(BLOB to real($buffer->; PC double real format; $o))
			: ($f.width>0)  // Real, Int64
				$p->:=BLOB to real($buffer->; PC double real format; $o)
			Else
				$size:=BLOB to longint($buffer->; PC byte ordering; $o)
				$at:=$o
				Case of 
					: ($f.kind=Is text)
						$t:=This._text($buffer; $o; $size)
						$p->:=(($t="") && $f.uuid) ? "00000000000000000000000000000000" : $t
					: ($f.kind=Is BLOB)
						SET BLOB SIZE($bytes; $size)
						COPY BLOB($buffer->; $bytes; $o; 0; $size)
						$p->:=$bytes
					: ($f.kind=Is picture)
						BLOB TO VARIABLE($buffer->; $pic; $at)
						$p->:=$pic
					: ($size=0)  // Object
						$p->:=Null
					Else
						BLOB TO VARIABLE($buffer->; $obj; $at)
						$p->:=$obj
				End case
				$o+=$size
		End case
	End for each


Function slices($buffer : Pointer; $offset : Integer) : Collection
	// Each field's byte range in the buffer, its length included, in field order: [{start; size}].
	var $slices : Collection
	var $f : Object
	var $o; $size : Integer
	$slices:=[]
	$o:=$offset
	For each ($f; This._fields)
		$size:=This._size($buffer; $o; $f)
		$slices.push({start: $o; size: $size})
		$o+=$size
	End for each
	return $slices


Function readable($buffer : Pointer; $offset : Integer; $i : Integer) : Variant
	// Field $i's value, read from its slice at $offset, as Compare's report
	// shows it (spec 08): a Boolean or a number as it is, a date as
	// yyyy-mm-dd, a time as hh:mm:ss, a text for Alpha, Text, UUID and object
	// (as JSON), and {bytes; sha256} for a BLOB or a picture.
	var $bytes : Blob
	var $f; $obj : Object
	var $o; $n; $size : Integer
	$f:=This._fields[$i]
	$o:=$offset
	Case of
		: ($f.kind=Is boolean)
			return ($buffer->{$o}=1)
		: ($f.kind=Is longint)
			return BLOB to longint($buffer->; PC byte ordering; $o)
		: ($f.kind=Is date)
			$n:=BLOB to longint($buffer->; PC byte ordering; $o)
			return String($n\10000; "0000")+"-"+String(($n\100)%100; "00")+"-"+String($n%100; "00")
		: ($f.kind=Is time)
			return String(Time(BLOB to real($buffer->; PC double real format; $o)); HH MM SS)
		: ($f.width>0)  // Real, Int64
			return BLOB to real($buffer->; PC double real format; $o)
	End case
	$size:=BLOB to longint($buffer->; PC byte ordering; $o)  // moves $o to the value
	Case of
		: ($f.kind=Is text)
			return This._text($buffer; $o; $size)
		: ($f.kind=Is object)
			If ($size=0)
				return "{}"
			End if
			BLOB TO VARIABLE($buffer->; $obj; $o)
			return JSON Stringify($obj)
	End case
	SET BLOB SIZE($bytes; $size)
	COPY BLOB($buffer->; $bytes; $o; 0; $size)
	return {bytes: $size; sha256: Generate digest($bytes; SHA256 digest)}


Function _text($buffer : Pointer; $o : Integer; $size : Integer) : Text
	// The UTF-8 text at $o. Convert to text drops a leading BOM (EF BB BF), but
	// here those bytes are a U+FEFF that belongs to the value, so it goes back.
	var $bytes : Blob
	SET BLOB SIZE($bytes; $size)
	COPY BLOB($buffer->; $bytes; $o; 0; $size)
	If ($size>=3) && ($bytes{0}=239) && ($bytes{1}=187) && ($bytes{2}=191)
		return Char(65279)+Convert to text($bytes; "UTF-8")
	End if 
	return Convert to text($bytes; "UTF-8")
	
	
Function _size($buffer : Pointer; $o : Integer; $f : Object) : Integer
	// The size of the field's slice that starts at $o.
	If ($f.width>0)
		return $f.width
	End if
	return 4+BLOB to longint($buffer->; PC byte ordering; $o)


Function _fail($code : Integer; $message : Text)
	var $p : Pointer
	var $key : Text
	$key:="none"
	If (This._key>=0)
		$p:=This._key_ptr
		$key:=String($p->)
	End if
	throw({errCode: $code; componentSignature: "ExportImport"; message: "["+This.table+"] record key "+$key+": "+$message})
