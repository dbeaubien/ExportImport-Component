//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Spike_Save_Result (method; facts)
//
// DESCRIPTION
//   DEV ONLY. Writes a spike method's facts to
//   .scratch/exact-copy-v2-build/research/01-<method>-<compiled|interpreted>.json
//   and shows how many passed.
//
#DECLARE($method : Text; $facts : Collection)
// ----------------------------------------------------
var $build : Integer
var $result : Object
var $folder : 4D.Folder
var $file : 4D.File
$result:={method: $method; when: Timestamp; compiled: Is compiled mode}
$result.app_version:=Application version($build)
$result.app_build:=$build
$result.data_language:=Get database localization(Internal 4D localization; *)
$result.facts:=$facts
$folder:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research")
$folder.create()
$file:=$folder.file("01-"+$method+"-"+(Is compiled mode ? "compiled" : "interpreted")+".json")
$file.setText(JSON Stringify($result; *))
ALERT($method+": "+String($facts.countValues(True; "pass"))+" of "+String($facts.length)+" facts passed."+Char(Carriage return)+$file.path)
