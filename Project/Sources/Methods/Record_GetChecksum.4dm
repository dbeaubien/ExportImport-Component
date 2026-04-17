//%attributes = {"invisible":true,"preemptive":"capable"}
// Record_GetChecksum (tablePtr) : checksum
// Record_GetChecksum (pointer) : text
// 
// DESCRIPTION
//   Generates a checksum for the current record of the table.
//
#DECLARE($tablePtr : Pointer)->$checksum : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

var $tableNo : Integer
$tableNo:=Table:C252($tablePtr)

ARRAY TEXT:C222($fieldValueArr; 0)
ARRAY TEXT:C222($fieldNameArr; 0)
var $fieldValue : Text

// gather all the stored data from the current row/record
var $vx_tmpBLOB : Blob
var $fieldNo; $fieldType : Integer
var $fieldPtr : Pointer
For ($fieldNo; 1; Get last field number:C255($tablePtr))
	If (Not:C34(Is field number valid:C1000($tableNo; $fieldNo)))
		continue
	End if 
	
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
End for 
SET BLOB SIZE:C606($vx_tmpBLOB; 0)

// Sort by field names, more resilient when comparing tables with the same field names
SORT ARRAY:C229($fieldNameArr; $fieldValueArr; >)

// combine the sorted field values into a single text block in prep for a MD5 digest
var $i : Integer
var $rowRAW : Text
For ($i; 1; Size of array:C274($fieldValueArr))
	$rowRAW:=$rowRAW+$fieldValueArr{$i}+Char:C90(Carriage return:K15:38)
End for 

$checksum:=STR_GetChecksum_MD5($rowRAW)
