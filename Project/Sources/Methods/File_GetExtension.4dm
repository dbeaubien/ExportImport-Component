//%attributes = {"invisible":true,"preemptive":"capable"}
// File_GetExtension (filePath) : fileExtension
// 
// DESCRIPTION
//   Returns the extension from a filename
//
#DECLARE($path : Text)->$file_extension : Text
// ----------------------------------------------------

var $i; $position : Integer
For ($i; Length:C16($path); 1; -1)
	Case of 
		: ($path[[$i]]=".")
			$position:=$i
			break
			
		: ($path[[$i]]=Folder separator:K24:12) && ($i#Length:C16($path))  // end of file name
			break
			
	End case 
End for 

$file_extension:=($position>0) ? Substring:C12($path; $position+1) : ""
