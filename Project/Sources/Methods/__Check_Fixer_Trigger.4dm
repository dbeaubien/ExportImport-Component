//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Fixer_Trigger : calls
//
// DESCRIPTION
//   DEV ONLY. For __Check_Fixer: saves a c06_trigger record into
//   [Spike_Keys], deletes it, and returns how many times the table's
//   trigger ran for the save: 1 with triggers on, 0 with them off.
//
#DECLARE() : Integer
var $before; $calls : Integer
$before:=Storage.spike.trigger_calls
CREATE RECORD([Spike_Keys])
[Spike_Keys]PK:="c06_trigger"
[Spike_Keys]Alt_Code:="c06_trigger"
SAVE RECORD([Spike_Keys])
$calls:=Storage.spike.trigger_calls-$before
QUERY([Spike_Keys]; [Spike_Keys]PK="c06_trigger")
DELETE SELECTION([Spike_Keys])
return $calls
