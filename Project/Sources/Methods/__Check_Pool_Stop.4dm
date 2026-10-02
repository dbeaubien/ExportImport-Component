//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Pool_Stop (stop; ticks)
//
// DESCRIPTION
//   DEV ONLY. For __Check_Pool and __Check_Fixer: sets stop.requested
//   ticks after it starts (a second if 0), as the dialog's Stop does.
//
#DECLARE($stop : Object; $ticks : Integer)
// ----------------------------------------------------
DELAY PROCESS(Current process; ($ticks=0) ? 60 : $ticks)
Use ($stop)
	$stop.requested:=True
End use
