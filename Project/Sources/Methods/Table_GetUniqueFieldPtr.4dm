//%attributes = {"invisible":true,"preemptive":"capable"}
// Table_GetUniqueFieldPtr (tablePtr) : uniqueFieldPtr
// 
// DESCRIPTION
//   This method returns a pointer to the unique
//   field for the specified table
//
#DECLARE($tablePtr : Pointer)->$uniqueRecIDField : Pointer
// ----------------------------------------------------
// HISTORY
//   Created by: DB (08/09/08)
//   Mod: DB (10/23/2011) - Enhanced some error checking
//   Mod by: Dani Beaubien (04/02/2019) - pre-emptive capable
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

var $table_name : Text
$table_name:=Table name:C256($tablePtr)

var $primary_key_field_no : Integer
If ($table_name#"")
	var $primary_key_field_name : Text
	$primary_key_field_name:=ds:C1482[$table_name].getInfo().primaryKey
	
	If ($primary_key_field_name#"")
		$primary_key_field_no:=ds:C1482[$table_name][$primary_key_field_name].fieldNumber
	End if 
End if 

If ($primary_key_field_no<1)
	$primary_key_field_no:=1
End if 

$uniqueRecIDField:=Field:C253(Table:C252($tablePtr); $primary_key_field_no)