//%attributes = {"invisible":true,"preemptive":"incapable"}
// Worker_NTS_SetDatabaseParameter (table_no; sequence_number)
//
// ***** NOT THREAD SAFE *****
//
#DECLARE($table_no : Integer; $sequence_number : Integer)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=2)

If (Is table number valid:C999($table_no))
	SET DATABASE PARAMETER:C642(Table:C252($table_no)->; Table sequence number:K37:31; $sequence_number)
End if 