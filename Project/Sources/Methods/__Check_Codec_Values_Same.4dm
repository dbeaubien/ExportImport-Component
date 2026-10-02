//%attributes = {"invisible":true,"preemptive":"capable"}
// __Check_Codec_Values_Same (a; b; path; diffs)
//
// DESCRIPTION
//   DEV ONLY. Compares two values by value, never through the codec, and
//   pushes each difference onto diffs as {field: path; source; decoded}
//   (spec 23). Both must have the same type. A text is equal by its char
//   codes (= ignores case and reads @ as a wildcard), a real by its 8 bytes
//   (= may apply a tolerance, and -0 = +0), a picture by Picture size, its
//   formats and Equal pictures, a 4D.Blob by its size and SHA-256, an object
//   by its keys in order and then each value, a collection item by item, and
//   null matches null. Anything else (longint, boolean, date, time) by =.
//
#DECLARE($a : Variant; $b : Variant; $path : Text; $diffs : Collection)
// ----------------------------------------------------
var $oa; $ob : Object
var $ca; $cb; $la; $lb : Collection
var $pa; $pb; $mask : Picture
var $ra; $rb : Real
var $ta; $tb; $k : Text
var $x; $y : Blob
var $i : Integer
var $same : Boolean
ARRAY TEXT($fa; 0)
ARRAY TEXT($fb; 0)

If (Value type($a)#Value type($b))
	$diffs.push({field: $path; source: "a value of type "+String(Value type($a)); decoded: "a value of type "+String(Value type($b))})
	return
End if
Case of
	: (Value type($a)=Is null) || (Value type($a)=Is undefined)
		$same:=True
	: (Value type($a)=Is text)
		$ta:=$a
		$tb:=$b
		$same:=(Length($ta)=Length($tb)) && (Compare strings($ta; $tb; sk char codes)=0)
	: (Value type($a)=Is real)
		$ra:=$a
		$rb:=$b
		REAL TO BLOB($ra; $x; PC double real format)
		REAL TO BLOB($rb; $y; PC double real format)
		$same:=(Generate digest($x; SHA256 digest)=Generate digest($y; SHA256 digest))
	: (Value type($a)=Is picture)
		$pa:=$a
		$pb:=$b
		GET PICTURE FORMATS($pa; $fa)
		GET PICTURE FORMATS($pb; $fb)
		$la:=[]
		$lb:=[]
		ARRAY TO COLLECTION($la; $fa)
		ARRAY TO COLLECTION($lb; $fb)
		$same:=(Picture size($pa)=Picture size($pb)) && (JSON Stringify($la)=JSON Stringify($lb)) && ((Picture size($pa)=0) || Equal pictures($pa; $pb; $mask))
		$a:={size: Picture size($pa); formats: $la}  // readable, for the difference
		$b:={size: Picture size($pb); formats: $lb}
	: (Value type($a)=Is collection)
		$ca:=$a
		$cb:=$b
		$same:=($ca.length=$cb.length)
		If ($same)
			For ($i; 0; $ca.length-1)
				__Check_Codec_Values_Same($ca[$i]; $cb[$i]; $path+"["+String($i)+"]"; $diffs)
			End for
			return
		End if
		$a:="a collection of "+String($ca.length)
		$b:="a collection of "+String($cb.length)
	: (Value type($a)=Is object)
		$oa:=$a
		$ob:=$b
		If (OB Instance of($oa; 4D.Blob))
			$x:=$a
			$y:=$b
			$same:=(BLOB size($x)=BLOB size($y)) && (Generate digest($x; SHA256 digest)=Generate digest($y; SHA256 digest))
			$a:={bytes: BLOB size($x); sha256: Generate digest($x; SHA256 digest)}
			$b:={bytes: BLOB size($y); sha256: Generate digest($y; SHA256 digest)}
		Else
			$same:=(JSON Stringify(OB Keys($oa))=JSON Stringify(OB Keys($ob)))
			If ($same)
				For each ($k; OB Keys($oa))
					__Check_Codec_Values_Same($oa[$k]; $ob[$k]; ($path="") ? $k : $path+"."+$k; $diffs)
				End for each
				return
			End if
			$a:=OB Keys($oa)
			$b:=OB Keys($ob)
		End if
	Else   // longint, boolean, date, time
		$same:=($a=$b)
End case
If (Not($same))
	$diffs.push({field: $path; source: $a; decoded: $b})
End if
