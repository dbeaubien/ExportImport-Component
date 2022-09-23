//%attributes = {"invisible":true,"preemptive":"capable"}
// Trigger_ENABLE ()
// 
// DESCRIPTION
//   Uses 4D's ALTER DATABASE to enable all set triggers.
//

Begin SQL
	ALTER DATABASE ENABLE TRIGGERS;
End SQL
Log_INFO_FORCED("WARNING: All database triggers enabled")