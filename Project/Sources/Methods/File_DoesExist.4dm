//%attributes = {"invisible":true,"preemptive":"capable"}
// File_DoesExist (path to file) : does exist
// File_DoesExist (text) : boolean
// 
// DESCRIPTION:
//   Returns true if the file exists. 
//   It will create any parent folders if missing.
//
#DECLARE($file_path : Text)->$does_file_exist : Boolean
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

If ($file_path="")
	return 
End if 

Folder_VerifyExistance(Folder_ParentName($file_path))  // ensure the parent folder exists
$does_file_exist:=(Test path name:C476($file_path)=Is a document:K24:1)