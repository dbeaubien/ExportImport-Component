//%attributes = {"invisible":true,"preemptive":"capable"}
// Folder_ParentName (folderPath) : parentFolderPath
//
// DESCRIPTION
//   Returns the Parent Name of the file pathname we pass in
#DECLARE($folder_path : Text)->$parent_folder_path : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

If ($folder_path=("@"+Folder separator:K24:12))
	$folder_path:=Substring:C12($folder_path; 1; Length:C16($folder_path)-1)
End if 

var $path_parts : Collection
$path_parts:=Split string:C1554($folder_path; Folder separator:K24:12)

var $ignored : Text
$ignored:=$path_parts.pop()

$parent_folder_path:=$path_parts.join(Folder separator:K24:12)
If ($parent_folder_path#"")
	$parent_folder_path+=Folder separator:K24:12
End if 
