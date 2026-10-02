//%attributes = {"invisible":true,"preemptive":"capable"}
// Database_SetConstraints (on)
//
// DESCRIPTION
//   Turns the database's constraints on or off, for every process (spec
//   07), with ALTER DATABASE. Off, a saved record keeps its Auto UUID and
//   autoincrement values as assigned, and uniqueness isn't checked. 4D
//   refuses to turn them off while a log file is open (ticket 01's fact 10).
//   A method, as Database_SetTriggers.
//
#DECLARE($on : Boolean)
// ----------------------------------------------------
If ($on)
	Begin SQL
		ALTER DATABASE ENABLE CONSTRAINTS;
	End SQL
Else
	Begin SQL
		ALTER DATABASE DISABLE CONSTRAINTS;
	End SQL
End if
