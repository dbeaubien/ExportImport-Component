//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Bench_Plant ({remove_blocker})
//
// DESCRIPTION
//   DEV ONLY. Plants what the dialog's Health check and Export steps are
//   checked with (tickets 17 and 21), on a datafile from __Bench_Generate:
//   a bad character, Char(1), at the end of the Name of 3 [Bench_Small_01]
//   records, and a blocker in [Bench_Small_02], whose record with ID 1 gets
//   the blank key 0. remove_blocker True gives that record its ID 1 back.
//   The fixer removes the bad characters.
//
#DECLARE($remove_blocker : Boolean)
// ----------------------------------------------------
If ($remove_blocker)
	QUERY([Bench_Small_02]; [Bench_Small_02]ID=0)
	[Bench_Small_02]ID:=1
	SAVE RECORD([Bench_Small_02])
Else
	ALL RECORDS([Bench_Small_01])
	REDUCE SELECTION([Bench_Small_01]; 3)
	APPLY TO SELECTION([Bench_Small_01]; [Bench_Small_01]Name:=[Bench_Small_01]Name+Char(1))
	UNLOAD RECORD([Bench_Small_01])
	QUERY([Bench_Small_02]; [Bench_Small_02]ID=1)
	[Bench_Small_02]ID:=0
	SAVE RECORD([Bench_Small_02])
End if
UNLOAD RECORD([Bench_Small_02])
