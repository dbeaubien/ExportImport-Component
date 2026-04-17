//%attributes = {"invisible":true,"preemptive":"capable"}
// Table_Journaling_DISABLE (tablePtr)
// 
// DESCRIPTION
//   Uses 4D's ALTER DATABASE to disable all triggers.
//
#DECLARE($tablePtr : Pointer)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

var $tableName : Text
$tableName:=Table name:C256($tablePtr)

var sql : Text  // cannot use a local var for this
sql:="ALTER TABLE ["+$tableName+"] DISABLE LOG;"
Begin SQL
	EXECUTE IMMEDIATE :sql;
End SQL

Log_INFO_FORCED("WARNING: Table Journaling DISABLED for table ["+$tableName+"]!")
