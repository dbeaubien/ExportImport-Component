//%attributes = {"invisible":true,"preemptive":"capable"}
// Folder_DoesExist (path to folder) : doesExist
// 
// DESCRIPTION:
//   Returns true if the folder exists
#DECLARE($path_to_folder : Text)->$does_folder_exist : Boolean
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

If ($path_to_folder#"")
	$does_folder_exist:=(Test path name:C476($path_to_folder)=Is a folder:K24:2)
End if 
