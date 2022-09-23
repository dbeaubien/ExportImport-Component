//%attributes = {"invisible":true,"preemptive":"capable"}
// Record_GetChecksum (tablePtr) : checksum
// Record_GetChecksum (pointer) : text
// 
// DESCRIPTION
//   Generates a checksum for the current record of the table.
//
C_POINTER:C301($1; $tablePtr)
C_TEXT:C284($0; $checksum)

$checksum:=""
If (Asserted:C1132(Count parameters:C259=1))
	$tablePtr:=$1
	
	C_LONGINT:C283($tableNo)
	$tableNo:=Table:C252($tablePtr)
	
	ARRAY TEXT:C222($fieldValueArr; 0)
	ARRAY TEXT:C222($fieldNameArr; 0)
	C_TEXT:C284($fieldValue)
	
	// gather all the stored data from the current row/record
	C_LONGINT:C283($fieldNo; $fieldType)
	C_POINTER:C301($fieldPtr)
	C_BLOB:C604($vx_tmpBLOB)
	For ($fieldNo; 1; Get last field number:C255($tablePtr))
		If (Is field number valid:C1000($tableNo; $fieldNo))
			$fieldPtr:=Field:C253($tableNo; $fieldNo)
			$fieldType:=Type:C295($fieldPtr->)
			$fieldValue:=""
			
			Case of 
				: ($fieldType=Is object:K8:27)
					If ($fieldPtr#Null:C1517)  // a way to get a consistent string representation of an object
						var $json : Text
						var $objectLines : Collection
						$json:=JSON Stringify:C1217($fieldPtr->)
						$json:=Replace string:C233($json; "}"; "\r}")  // do this so that the order of stuff in the object won't matter
						$json:=Replace string:C233($json; "{"; "{\r")
						$json:=Replace string:C233($json; ","; "\r")
						$objectLines:=Split string:C1554($json; "\r"; sk ignore empty strings:K86:1).orderBy(ck ascending:K85:9)
						$fieldValue:=$objectLines.join(",")
					End if 
					
				: ($fieldType=Is picture:K8:10)
					SET BLOB SIZE:C606($vx_tmpBLOB; 0)
					VARIABLE TO BLOB:C532($fieldPtr->; $vx_tmpBLOB)
					$fieldValue:=Generate digest:C1147($vx_tmpBLOB; MD5 digest:K66:1)
					
				: ($fieldType=Is BLOB:K8:12)
					$fieldValue:=Generate digest:C1147($fieldPtr->; MD5 digest:K66:1)
					
				Else 
					$fieldValue:=FieldData_2Text($fieldPtr)
			End case 
			
			APPEND TO ARRAY:C911($fieldNameArr; Field name:C257($fieldPtr))
			APPEND TO ARRAY:C911($fieldValueArr; Field name:C257($fieldPtr)+":"+$fieldValue)
		End if 
	End for 
	SET BLOB SIZE:C606($vx_tmpBLOB; 0)
	
	// Sort by field names, more resilient when comparing tables with the same field names
	SORT ARRAY:C229($fieldNameArr; $fieldValueArr; >)
	
	// combine the sorted field values into a single text block in prep for a MD5 digest
	C_LONGINT:C283($i)
	C_TEXT:C284($rowRAW)
	$rowRAW:=""
	For ($i; 1; Size of array:C274($fieldValueArr))
		$rowRAW:=$rowRAW+$fieldValueArr{$i}+Char:C90(Carriage return:K15:38)
	End for 
	
	//SET TEXT TO PASTEBOARD($rowRAW)
	//TRACE
	
	$checksum:=STR_GetChecksum_MD5($rowRAW)
End if 

$0:=$checksum