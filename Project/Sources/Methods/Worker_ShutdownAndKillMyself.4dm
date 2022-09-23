//%attributes = {"invisible":true,"preemptive":"capable"}
// Worker_ShutdownAndKillMyself ()
//
// DESCRIPTION
//   Shuts down the worker and dumps any stats to disk.
//
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=0)

KILL WORKER:C1390(Current process:C322)