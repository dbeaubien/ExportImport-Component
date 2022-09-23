//%attributes = {"invisible":true,"preemptive":"capable"}
// Table_Journaling_ENABLE (tablePtr)
// 
// DESCRIPTION
//   Uses 4D's ALTER DATABASE to enable all triggers.
//
C_POINTER:C301($1; $tablePtr)

If (Asserted:C1132(Count parameters:C259=1))
	$tablePtr:=$1
	
	C_TEXT:C284($tableName)
	$tableName:=Table name:C256($tablePtr)
	
	C_TEXT:C284(sql)  // cannot use a local var for this
	sql:="ALTER TABLE ["+$tableName+"] ENABLE LOG;"
	Begin SQL
		--ALTER TABLE dialogs ENABLE LOG;
		EXECUTE IMMEDIATE :sql;
	End SQL
	
	Log_INFO_FORCED("WARNING: Table Journaling ENABLED for table ["+$tableName+"]!")
End if 