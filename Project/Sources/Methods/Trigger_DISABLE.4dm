//%attributes = {"invisible":true,"preemptive":"capable"}
// Trigger_DISABLE ()
// 
// DESCRIPTION
//   Uses 4D's ALTER DATABASE to disable all triggers.
//

Begin SQL
	ALTER DATABASE DISABLE TRIGGERS;
End SQL
Log_INFO_FORCED("WARNING: All database triggers DISABLED!")