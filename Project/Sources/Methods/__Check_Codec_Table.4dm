//%attributes = {"invisible":true,"preemptive":"capable"}
// __Check_Codec_Table (table; step; out)
//
// DESCRIPTION
//   DEV ONLY. One worker job of __Check_Codec. For every step-th record of
//   the table, in record-number order: encode, check the slices and the key,
//   decode into a new unsaved record, encode again and compare the bytes.
//   Int64 errors are listed apart. digest chains each buffer's SHA-256, to
//   compare runs on two machines. Pushes its result, as JSON text, onto
//   out.results.
//
#DECLARE($table : Object; $step : Integer; $out : Object)
// ----------------------------------------------------
var $codec : cs._Codec
var $result; $slice : Object
var $slices; $errors : Collection
var $a; $b : Blob
var $ptr; $key_ptr : Pointer
var $i; $j; $k; $end : Integer
var $digest; $key; $value : Text
var $ok : Boolean
ARRAY LONGINT($records; 0)

$result:={table: $table.name; preemptive: Process info(Current process).preemptive; records: 0; checked: 0; differ: 0; bad_slices: 0; bad_keys: 0; errors: 0; int64_errors: []; samples: []}
Try
	$codec:=cs._Codec.new($table)
	$ptr:=Table($table.number)
	$key_ptr:=Field($table.number; $table.primary_key)
	ALL RECORDS($ptr->)
	SELECTION TO ARRAY($ptr->; $records)
	$result.records:=Size of array($records)
	For ($i; 1; Size of array($records); $step)
		GOTO RECORD($ptr->; $records{$i})
		$key:=String($key_ptr->)
		Try
			$a:=$codec.encode()
			$digest:=Generate digest($digest+Generate digest($a; SHA256 digest); SHA256 digest)

			// The slices cover the buffer exactly
			$slices:=$codec.slices(->$a; 0)
			$ok:=($slices.length=$table.fields.length)
			$end:=0
			For each ($slice; $slices)
				$ok:=$ok && ($slice.start=$end)
				$end:=$slice.start+$slice.size
			End for each
			If (Not($ok && ($end=BLOB size($a))))
				$result.bad_slices+=1
				If ($result.samples.length<100)
					$result.samples.push({record: $records{$i}; key: $key; problem: "slices"; slices: $slices; size: BLOB size($a)})
				End if
			End if

			// key() reads the record key
			$value:=String($codec.key(->$a; 0).value)
			If (Not((Length($value)=Length($key)) && (Position($value; $key; 1; *)=1)))
				$result.bad_keys+=1
				If ($result.samples.length<100)
					$result.samples.push({record: $records{$i}; key: $key; problem: "key"; value: $value})
				End if
			End if

			// Decoded into a new record, it encodes to the same bytes
			CREATE RECORD($ptr->)
			$codec.decode(->$a; 0)
			$b:=$codec.encode()
			If ((BLOB size($a)#BLOB size($b)) || (Generate digest($a; SHA256 digest)#Generate digest($b; SHA256 digest)))
				$result.differ+=1
				If ($result.samples.length<100)
					$j:=0
					While (($j<BLOB size($a)) && ($j<BLOB size($b)) && ($a{$j}=$b{$j}))
						$j+=1
					End while
					$k:=0
					While (($k<($slices.length-1)) && ($slices[$k+1].start<=$j))
						$k+=1
					End while
					$result.samples.push({record: $records{$i}; key: $key; problem: "bytes"; first_byte: $j; field: $table.fields[$k].name; sizes: [BLOB size($a); BLOB size($b)]})
				End if
			End if
			$result.checked+=1
		Catch
			$errors:=Last errors
			If ($errors.query("componentSignature = :1 AND errCode = :2"; "ExportImport"; 2).length>0)
				$result.int64_errors.push({record: $records{$i}; key: $key; errors: $errors})
			Else
				$result.errors+=1
				If ($result.samples.length<100)
					$result.samples.push({record: $records{$i}; key: $key; problem: "error"; errors: $errors})
				End if
			End if
		End try
	End for
	REDUCE SELECTION($ptr->; 0)
Catch
	$result.errors+=1
	$result.samples.push({problem: "the table stopped"; errors: Last errors})
End try
$result.digest:=$digest

Use ($out.results)
	$out.results.push(JSON Stringify($result))
End use
