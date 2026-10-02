//%attributes = {"invisible":true,"preemptive":"capable"}
// __Spike_Encode_Arrays (ptrs; kinds; widths; uuids) : Blob
//
// DESCRIPTION
//   DEV ONLY (spec ticket 17's probe, throw-away). _Codec.encode() with the
//   field descriptors read from arrays, by pointer, so the per-record loop
//   makes no object, collection or class operation. Returns the current
//   record's canonical buffer, byte for byte encode()'s, and throws where
//   encode() fails (codes 1 to 3, without the record key).
//
#DECLARE($ptrs : Pointer; $kinds : Pointer; $widths : Pointer; $uuids : Pointer) : Blob
// ----------------------------------------------------
var $buffer; $bytes : Blob
var $p : Pointer
var $i; $o; $kind : Integer
var $r : Real
var $d : Date
var $t : Text
var $pic : Picture
var $obj : Object
For ($i; 1; Size of array($ptrs->))
	$p:=$ptrs->{$i}
	$kind:=$kinds->{$i}
	If ($widths->{$i}>0)
		Case of
			: ($kind=Is boolean)
				SET BLOB SIZE($buffer; $o+1)
				$buffer{$o}:=Num($p->)
				$o+=1
			: ($kind=Is longint)
				LONGINT TO BLOB($p->; $buffer; PC byte ordering; $o)
			: ($kind=Is date)  // yyyymmdd, blank = 0
				$d:=$p->
				LONGINT TO BLOB((Year of($d)*10000)+(Month of($d)*100)+Day of($d); $buffer; PC byte ordering; $o)
			: ($kind=Is time)  // seconds
				REAL TO BLOB($p->+0; $buffer; PC double real format; $o)
			Else   // Real, and Int64, which the language reads as a Real
				$r:=$p->
				If ($kind=Is integer 64 bits) && (Abs($r)>(2^53))
					throw({errCode: 2; componentSignature: "ExportImport"; message: "an Int64 value beyond ±2^53"})
				End if
				REAL TO BLOB($r; $buffer; PC double real format; $o)
		End case
	Else
		SET BLOB SIZE($bytes; 0)
		Case of
			: ($uuids->{$i})
				$t:=$p->
				If ($t#"") && ($t#"00000000000000000000000000000000")
					CONVERT FROM TEXT($t; "UTF-8"; $bytes)
				End if
			: ($kind=Is text)
				$t:=$p->
				If (Match regex("[\\x{D800}-\\x{DFFF}]"; $t; 1))  // a pair is one code point, so only a lone surrogate matches
					throw({errCode: 3; componentSignature: "ExportImport"; message: "a lone surrogate, which UTF-8 can't hold"})
				End if
				CONVERT FROM TEXT($t; "UTF-8"; $bytes)
			: ($kind=Is BLOB)
				$bytes:=$p->
			: ($kind=Is picture)
				$pic:=$p->
				VARIABLE TO BLOB($pic; $bytes)
			Else   // Object
				$obj:=$p->
				If (Not(OB Is empty($obj)))
					VARIABLE TO BLOB($obj; $bytes)
				End if
		End case
		If (BLOB size($bytes)>(MAXLONG-4-$o))  // written so that it can't overflow
			throw({errCode: 1; componentSignature: "ExportImport"; message: "the buffer would pass the 2 GB limit"})
		End if
		LONGINT TO BLOB(BLOB size($bytes); $buffer; PC byte ordering; $o)
		SET BLOB SIZE($buffer; $o+BLOB size($bytes))
		COPY BLOB($bytes; $buffer; 0; $o; BLOB size($bytes))
		$o+=BLOB size($bytes)
	End if
End for
return $buffer
