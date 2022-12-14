//%attributes = {"invisible":true,"shared":true,"preemptive":"incapable"}
// Export_AllTables (num_workers{; fields_to_base64})
//
var $1; $num_workers : Integer
var $2; $fields_to_base64 : Collection
var $0; $export_folder_platformPath : Text
ASSERT:C1129(Count parameters:C259<=2)
If (Count parameters:C259>=1)
	$num_workers:=$1
End if 
If (Count parameters:C259>=2)
	$fields_to_base64:=$2
End if 
If ($num_workers<=0)
	$num_workers:=3
End if 
If ($fields_to_base64=Null:C1517)
	$fields_to_base64:=New collection:C1472()
End if 

var $table_no_list : Collection
var $table_no : Integer
$table_no_list:=New collection:C1472()
For ($table_no; 1; Get last table number:C254)
	Case of 
		: (Not:C34(Is table number valid:C999($table_no)))
		: (Records in table:C83(Table:C252($table_no)->)=0)
		Else 
			$table_no_list.push($table_no)
	End case 
End for 

$export_folder_platformPath:=Export_ListOfTables($num_workers; $table_no_list; $fields_to_base64)

$0:=$export_folder_platformPath