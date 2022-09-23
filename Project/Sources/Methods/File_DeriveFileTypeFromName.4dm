//%attributes = {"invisible":true,"preemptive":"capable"}
// ----------------------------------------------------
// METHOD: File_DeriveFileTypeFromName
// 
// DESCRIPTION
//   Figure out what the file type is basd on the file name.
//
// PARAMETERS:
C_TEXT:C284($1; $vt_fileName)
//
// RETURNS:
C_TEXT:C284($0; $vt_FileType)
// ----------------------------------------------------
// CALLED BY
//   
// ----------------------------------------------------
// HISTORY
//   Created by: DB (10/26/07)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
$vt_FileType:=""
$vt_fileName:=$1

// Get our file extn. If windows, then we are done
$vt_FileType:=File_GetExtension($vt_fileName)

// If mac, then we have more work to do
If (Is macOS:C1572)
	Case of 
		: ($vt_FileType="xls") | ($vt_FileType="slk")
			$vt_FileType:="XLS8"
			
		Else   // by default
			$vt_FileType:="TEXT"
	End case 
End if 

$0:=$vt_FileType