//%attributes = {"invisible":true,"preemptive":"capable"}
// File_GetChecksum (filePath; hashAlgorithm) : checksum
// File_GetChecksum (text; text) : text
// 
// DESCRIPTION
//   This method returns the checksum for a file.
//   Supported hash algorithms of "mdf5" or "sha1",
//    everything else resolves to "md5"
//   NOTE: The file is loaded into memory.
//
C_TEXT:C284($1; $vt_filePath)
C_TEXT:C284($2; $vt_hash_algorithm)
C_TEXT:C284($0; $checksum_out_t)
// ----------------------------------------------------
//   Created by: Timothy Penner (06/15/2010)
//   Mod: DB (10/19/2011) - Added to IH_Core
//   Mod by: Dani Beaubien (07/31/2017) - Using built in 4D command to avoid PHP
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=2)
$vt_filePath:=$1
$vt_hash_algorithm:=$2

If (File_DoesExist($vt_filePath))
	OnErr_Install_Handler("OnErr_GENERIC")
	
	C_BLOB:C604($FirstBlob)
	C_TIME:C306($vhDocRef1)
	$vhDocRef1:=Open document:C264($vt_filePath; "*"; Read mode:K24:5)
	If (OK=1)  // If a document is selected
		DOCUMENT TO BLOB:C525(Document; $FirstBlob)  // Load document
		If (OK=1)
			Case of 
				: ($vt_hash_algorithm="md5")
					$checksum_out_t:=Generate digest:C1147($FirstBlob; MD5 digest:K66:1)
				: ($vt_hash_algorithm="sha1")
					$checksum_out_t:=Generate digest:C1147($FirstBlob; SHA1 digest:K66:2)
				Else 
					$checksum_out_t:=Generate digest:C1147($FirstBlob; MD5 digest:K66:1)
			End case 
		End if 
		
		CLOSE DOCUMENT:C267($vhDocRef1)
	End if 
	SET BLOB SIZE:C606($FirstBlob; 0)
	
	OnErr_Install_Handler
End if 

$0:=$checksum_out_t
