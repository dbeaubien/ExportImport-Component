//%attributes = {"invisible":true,"preemptive":"capable"}
// OnErr_Clear ()
// 
// DESCRIPTION
//   Clears the internal error var
//
// ----------------------------------------------------
// HISTORY
//   Created by: DB (09/13/2016)
// ----------------------------------------------------

ARRAY TEXT:C222(gErrorTextArr; 0)
C_LONGINT:C283(gError)
gError:=0