//%attributes = {"invisible":true,"preemptive":"capable"}
// Table_GenerateChecksumFile (uniqueFld; recsPerBlock; destFldr) : checksumFile
// 
// DESCRIPTION
//   Generates a checksum file for the specified table.
//
//   The 1st parm is a ptr to the "id" field of the table
//   that will be checksum'd.
//
#DECLARE($uniqueFieldPtr : Pointer\
; $maxRowsPerBlock : Integer\
; $destinationFolder : Text\
; $progHdl : Integer)->$pathToChecksumFile : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=4)
$pathToChecksumFile:=""

// Get the table from our unique field ptr
var $table_no : Integer
var $tablePtr : Pointer
$table_no:=Table:C252($uniqueFieldPtr)
$tablePtr:=Table:C252($table_no)

// if not a valid parm, then set to 1/1000 of the table size
If ($maxRowsPerBlock=0)
	$maxRowsPerBlock:=Int:C8(Records in table:C83($tablePtr->)/1000)
	If ($maxRowsPerBlock<10)
		$maxRowsPerBlock:=10
	End if 
End if 

// Load all the records in a fixed sort order
ALL RECORDS:C47($tablePtr->)
ORDER BY:C49($tablePtr->; $uniqueFieldPtr->; >)

// Loop through every record gathering the information to build
// a checksum for each block and a final checksum for the entire
// table.
C_TEXT:C284($rowChecksum; $firstRecordUniqueFldValue; $vt_tableRAW; $vt_rowRAW)
C_LONGINT:C283($blockNo; $rowsInBlockCount)
$blockNo:=0
$rowsInBlockCount:=0
$firstRecordUniqueFldValue:=""
$vt_tableRAW:=""
$vt_rowRAW:=""

// Output the gathered checksums to a temporary file
C_TEXT:C284($vt_path2File; $vt_header)
C_TIME:C306($docRef)
$vt_path2File:=$destinationFolder+"p"+String:C10(Current process:C322)+"_"+String:C10(Milliseconds:C459)+".txt"
File_Delete($vt_path2File)
$docRef:=File_CreateFile($vt_path2File)
If ($docRef#-1)
	$vt_header:=""
	$vt_header:=$vt_header+"Table: "+Table name:C256($tablePtr)+Char:C90(Carriage return:K15:38)
	$vt_header:=$vt_header+"Rows Count: "+String:C10(Records in table:C83($tablePtr->))+" recs"+Char:C90(Carriage return:K15:38)
	$vt_header:=$vt_header+Char:C90(Carriage return:K15:38)
	SEND PACKET:C103($docRef; $vt_header)
	
	
	
	var $ms; $row : Integer
	Progress_Set_Title_ALT($progHdl; "Checksumming ["+Table name:C256($table_no)+"] records...")
	For ($row; 1; Records in selection:C76($tablePtr->))
		If ($ms<Milliseconds:C459)
			Progress_Set_Progress_ALT($progHdl; $row/Records in selection:C76($tablePtr->); "hashed "+String:C10($row; "###,###,###,##0")+" of "+String:C10(Records in selection:C76($tablePtr->); "###,###,###,##0"))
			$ms:=Milliseconds:C459+300  // next update
		End if 
		If ($rowsInBlockCount=0)  // start of a block
			$rowsInBlockCount:=0
			$blockNo:=$blockNo+1
			$firstRecordUniqueFldValue:=FieldData_2Text($uniqueFieldPtr)
		End if 
		
		// gather all the stored data from the current row/record
		$rowChecksum:=Record_GetChecksum($tablePtr)
		$rowsInBlockCount:=$rowsInBlockCount+1
		
		// detect if we are at the end of the block or not
		If ($rowsInBlockCount<$maxRowsPerBlock) & ($row#Records in selection:C76($tablePtr->))
			$vt_rowRAW:=$vt_rowRAW+$rowChecksum+Char:C90(Carriage return:K15:38)
			
		Else   // At the end of the block, do a block checksum
			If ($maxRowsPerBlock=1)
				$vt_tableRAW:=$vt_tableRAW+"Row "+String:C10($blockNo)+" ("+$firstRecordUniqueFldValue+") :"+$rowChecksum+Char:C90(Carriage return:K15:38)
			Else 
				If ($row=Records in selection:C76($tablePtr->))
					$maxRowsPerBlock:=$maxRowsPerBlock-1
				End if 
				$vt_tableRAW:=$vt_tableRAW+"Block "+String:C10($blockNo)+" Rows "+String:C10($row-$rowsInBlockCount+1)+"-"+String:C10($row)+" ("+$firstRecordUniqueFldValue+"->"+String:C10($uniqueFieldPtr->)+") :"
				$vt_tableRAW:=$vt_tableRAW+STR_GetChecksum_MD5($vt_rowRAW)+Char:C90(Carriage return:K15:38)
			End if 
			
			// output to disk if getting "large"
			If (Length:C16($vt_tableRAW)>2048)
				SEND PACKET:C103($docRef; $vt_tableRAW)
				//SEND PACKET($docRef;$vt_rowRAW)
				$vt_tableRAW:=""
			End if 
			
			// signal to start a new block
			$vt_rowRAW:=""
			$rowsInBlockCount:=0
		End if 
		
		NEXT RECORD:C51($tablePtr->)
	End for 
	
	SEND PACKET:C103($docRef; $vt_tableRAW)
	CLOSE DOCUMENT:C267($docRef)
End if 

// Generate the full table checksum for the table (used in the file name)
C_TEXT:C284($fileChecksum)
$fileChecksum:=File_GetChecksum($vt_path2File; "md5")

// Move the temp file to it's final name
$pathToChecksumFile:=$destinationFolder+"%t - %c - %n.txt"  // Final checksum file name
$pathToChecksumFile:=Replace string:C233($pathToChecksumFile; "%t"; Table name:C256($tablePtr))
$pathToChecksumFile:=Replace string:C233($pathToChecksumFile; "%c"; Uppercase:C13($fileChecksum))
$pathToChecksumFile:=Replace string:C233($pathToChecksumFile; "%n"; String:C10(Records in table:C83($tablePtr->))+" recs")
File_Delete($pathToChecksumFile)  // remove any older version 
MOVE DOCUMENT:C540($vt_path2File; $pathToChecksumFile)
