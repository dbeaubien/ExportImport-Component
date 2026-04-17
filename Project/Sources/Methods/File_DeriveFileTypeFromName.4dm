//%attributes = {"invisible":true,"preemptive":"capable"}
// ----------------------------------------------------
// METHOD: File_DeriveFileTypeFromName
// 
// DESCRIPTION
//   Figure out what the file type is basd on the file name.
//
#DECLARE($file_name : Text)->$file_type : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

// Get our file extn. If windows, then we are done
$file_type:=File_GetExtension($file_name)

If (Is Windows:C1573)
	return 
End if 

// If mac, then we have more work to do
Case of 
	: ($file_type="xls") || ($file_type="slk")
		$file_type:="XLS8"
		
	Else   // by default
		$file_type:="TEXT"
End case 
