//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Spike_Write_Facts
//
// DESCRIPTION
//   DEV ONLY. Ticket 01's spike, facts 10–14: the 4D facts about writing
//   records that the import relies on. Uses only the Spike_* tables,
//   which it truncates first. Turns constraints and triggers back on at the end.
//   Writes .scratch/exact-copy-v2-build/research/01-__Spike_Write_Facts-<compiled|interpreted>.json.
//
// ----------------------------------------------------
var $facts : Collection
var $f; $off; $on : Object
var $i; $n; $before : Integer
var $state; $key_value; $uuid : Text
var $blank : Boolean
ARRAY TEXT($all; 0)
$facts:=[]

TRUNCATE TABLE([Spike_Keys])
TRUNCATE TABLE([Spike_TextKey])
SET DATABASE PARAMETER([Spike_Keys]; Table sequence number; 0)
Use (Storage)
	Storage.spike:=New shared object("trigger_calls"; 0)
End use 

// ## Fact 10: with constraints off, Auto UUID and autoincrement keep what was assigned
$f:={fact: 10; spec: "07"; expected: "with constraints off, a blank Auto UUID and autoincrement stay blank (\"\" or all-zero UUID, 0) and set values stay as set, read with constraints off and then on"; pass: True; actual: {}}
Try
	Begin SQL
		ALTER DATABASE DISABLE CONSTRAINTS;
	End SQL
	CREATE RECORD([Spike_Keys])
	[Spike_Keys]PK:="w10_blank"
	[Spike_Keys]Alt_Code:="w10_blank"
	[Spike_Keys]Auto_UUID:=""
	[Spike_Keys]Auto_Num:=0
	$f.actual.save_blank:=__Spike_Save(->[Spike_Keys])
	CREATE RECORD([Spike_Keys])
	[Spike_Keys]PK:="w10_set"
	[Spike_Keys]Alt_Code:="w10_set"
	[Spike_Keys]Auto_UUID:="0123456789ABCDEF0123456789ABCDEF"
	[Spike_Keys]Auto_Num:=4242
	$f.actual.save_set:=__Spike_Save(->[Spike_Keys])
	UNLOAD RECORD([Spike_Keys])
	For each ($state; ["constraints_off"; "constraints_on"])
		If ($state="constraints_on")
			Begin SQL
				ALTER DATABASE ENABLE CONSTRAINTS;
			End SQL
		End if
		$f.actual[$state]:={}
		QUERY([Spike_Keys]; [Spike_Keys]PK="w10_@")
		While (Not(End selection([Spike_Keys])))
			$key_value:=[Spike_Keys]PK
			$uuid:=[Spike_Keys]Auto_UUID
			$f.actual[$state][$key_value]:={uuid: $uuid; num: [Spike_Keys]Auto_Num}
			If ($key_value="w10_blank")
				$blank:=(($uuid="") | ($uuid="00000000000000000000000000000000")) & ([Spike_Keys]Auto_Num=0)
				$f.pass:=$f.pass & $blank
			Else
				$f.pass:=$f.pass & ($uuid="0123456789ABCDEF0123456789ABCDEF") & ([Spike_Keys]Auto_Num=4242)
			End if
			NEXT RECORD([Spike_Keys])
		End while
		UNLOAD RECORD([Spike_Keys])
		$f.pass:=$f.pass & (Records in selection([Spike_Keys])=2)
	End for each
Catch
	$f.pass:=False
	$f.error:=Last errors
End try
$facts.push($f)

// ## Fact 11: a preemptive worker saves into a table with a trigger, with triggers off and on
$f:={fact: 11; spec: "07, 12"; expected: "compiled: the worker is preemptive and saves both records. The trigger runs with triggers on, and not with triggers off"; pass: False}
Try
	Begin SQL
		ALTER DATABASE DISABLE TRIGGERS;
	End SQL
	$before:=Storage.spike.trigger_calls
	$off:=__Spike_Call_Worker("save"; {table: Table(->[Spike_Keys]); pk: "w11_off"})
	$off.trigger_calls:=Storage.spike.trigger_calls-$before
	Begin SQL
		ALTER DATABASE ENABLE TRIGGERS;
	End SQL
	$before:=Storage.spike.trigger_calls
	$on:=__Spike_Call_Worker("save"; {table: Table(->[Spike_Keys]); pk: "w11_on"})
	$on.trigger_calls:=Storage.spike.trigger_calls-$before
	$f.actual:={triggers_off: $off; triggers_on: $on}
	If (Is compiled mode)
		$f.pass:=($off.preemptive=True) & ($off.saved=1) & ($off.trigger_calls=0) & ($on.saved=1) & ($on.trigger_calls=1)
	Else
		$f.pass:=Null  // interpreted workers are cooperative
	End if
Catch
	$f.error:=Last errors
End try
KILL WORKER("__Spike")
$facts.push($f)

// ## Fact 12: SAVE RECORD saves a record whose only non-blank value is its key
$f:={fact: 12; spec: "07"; expected: "with constraints off, as in the import, a record whose only non-blank value is its key is saved, in both spike tables"; pass: False; actual: {}}
Try
	Begin SQL
		ALTER DATABASE DISABLE CONSTRAINTS;
	End SQL
	CREATE RECORD([Spike_Keys])  // every field assigned, as the decoder does
	[Spike_Keys]PK:="w12_only_key"
	[Spike_Keys]Alt_Code:=""
	[Spike_Keys]Auto_UUID:=""
	[Spike_Keys]Auto_Num:=0
	[Spike_Keys]F_Text:=""
	[Spike_Keys]F_Date:=!00-00-00!
	$f.actual.save_Spike_Keys:=__Spike_Save(->[Spike_Keys])
	UNLOAD RECORD([Spike_Keys])
	CREATE RECORD([Spike_TextKey])
	[Spike_TextKey]PK:="w12_only_key"
	[Spike_TextKey]F_Text:=""
	$f.actual.save_Spike_TextKey:=__Spike_Save(->[Spike_TextKey])
	UNLOAD RECORD([Spike_TextKey])
	Begin SQL
		ALTER DATABASE ENABLE CONSTRAINTS;
	End SQL
	QUERY([Spike_Keys]; [Spike_Keys]PK="w12_only_key")
	$f.actual.found_Spike_Keys:=Records in selection([Spike_Keys])
	QUERY([Spike_TextKey]; [Spike_TextKey]PK="w12_only_key")
	$f.actual.found_Spike_TextKey:=Records in selection([Spike_TextKey])
	UNLOAD RECORD([Spike_Keys])
	UNLOAD RECORD([Spike_TextKey])
	$f.pass:=($f.actual.found_Spike_Keys=1) & ($f.actual.found_Spike_TextKey=1)
Catch
	$f.error:=Last errors
End try
$facts.push($f)

// ## Fact 13: RESUME INDEXES and ENABLE CONSTRAINTS with duplicates in a unique non-key field
$f:={fact: 13; spec: "09"; expected: "RESUME INDEXES and ENABLE CONSTRAINTS raise no error, and the indexed query and a scan both find the 2 duplicates"; pass: False; actual: {saves: []; resume_errors: []; enable_errors: []}}
Try
	Begin SQL
		ALTER DATABASE DISABLE CONSTRAINTS;
	End SQL
	PAUSE INDEXES([Spike_Keys])
	For each ($key_value; ["w13_a"; "w13_b"])
		CREATE RECORD([Spike_Keys])
		[Spike_Keys]PK:=$key_value
		[Spike_Keys]Alt_Code:="DUP"
		$f.actual.saves.push(__Spike_Save(->[Spike_Keys]))
	End for each
	UNLOAD RECORD([Spike_Keys])
	Try
		RESUME INDEXES([Spike_Keys])
	Catch
		$f.actual.resume_errors:=Last errors
	End try
	Try
		Begin SQL
			ALTER DATABASE ENABLE CONSTRAINTS;
		End SQL
	Catch
		$f.actual.enable_errors:=Last errors
	End try
	QUERY([Spike_Keys]; [Spike_Keys]Alt_Code="DUP")
	$f.actual.indexed_query:=Records in selection([Spike_Keys])
	ALL RECORDS([Spike_Keys])
	SELECTION TO ARRAY([Spike_Keys]Alt_Code; $all)
	$n:=0
	For ($i; 1; Size of array($all))
		$n:=$n+Num($all{$i}="DUP")
	End for
	$f.actual.scan:=$n
	CREATE RECORD([Spike_Keys])  // constraints are on again: is uniqueness enforced?
	[Spike_Keys]PK:="w13_c"
	[Spike_Keys]Alt_Code:="DUP"
	$f.actual.third_duplicate_save:=__Spike_Save(->[Spike_Keys])
	UNLOAD RECORD([Spike_Keys])
	$f.pass:=($f.actual.resume_errors.length=0) & ($f.actual.enable_errors.length=0) & ($f.actual.indexed_query=2) & ($f.actual.scan=2)
Catch
	$f.error:=Last errors
End try
QUERY([Spike_Keys]; [Spike_Keys]PK="w13_@")  // leave no duplicates in the unique index
DELETE SELECTION([Spike_Keys])
$facts.push($f)

// ## Fact 14: Get database parameter(table; 31) returns the value just set
$f:={fact: 14; spec: "07"; expected: "in a cooperative process, after records were created, Get database parameter(table; 31) returns each n just set"; pass: True; actual: {}}
Try
	$f.actual.records:=Records in table([Spike_Keys])
	$f.actual.before:=Get database parameter([Spike_Keys]; Table sequence number)
	For each ($n; [1000; 3])
		SET DATABASE PARAMETER([Spike_Keys]; Table sequence number; $n)
		$f.actual["after_set_"+String($n)]:=Get database parameter([Spike_Keys]; Table sequence number)
		$f.pass:=$f.pass & (Get database parameter([Spike_Keys]; Table sequence number)=$n)
	End for each
Catch
	$f.pass:=False
	$f.error:=Last errors
End try
$facts.push($f)

Begin SQL
	ALTER DATABASE ENABLE CONSTRAINTS;
	ALTER DATABASE ENABLE TRIGGERS;
End SQL
__Spike_Save_Result(Current method name; $facts)
