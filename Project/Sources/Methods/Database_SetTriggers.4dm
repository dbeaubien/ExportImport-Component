//%attributes = {"invisible":true,"preemptive":"capable"}
// Database_SetTriggers (on)
//
// DESCRIPTION
//   Turns every trigger of the database on or off, for every process
//   (spec 09), with ALTER DATABASE. A method, not a class function, so the
//   SQL block stays where this project has always run it.
//
#DECLARE($on : Boolean)
// ----------------------------------------------------
If ($on)
	Begin SQL
		ALTER DATABASE ENABLE TRIGGERS;
	End SQL
Else
	Begin SQL
		ALTER DATABASE DISABLE TRIGGERS;
	End SQL
End if
