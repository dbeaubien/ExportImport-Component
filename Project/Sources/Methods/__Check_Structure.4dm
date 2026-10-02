//%attributes = {"invisible":true,"shared":true,"preemptive":"incapable"}
// __Check_Structure
//
// DESCRIPTION
//   DEV ONLY. Ticket 02's host check: call it from a host with the component
//   installed. Writes what _Structure read (the tables and fields, the
//   signature and the data language) to __Check_Structure.json in the host's
//   data folder. The tables must be the host's, and the fields marked
//   never_null exactly those its catalog marks never_null="true".
//   Shared only so a host can call it.
//
// ----------------------------------------------------
var $structure : cs._Structure
var $table : Object
var $never_null : Integer
var $file : 4D.File
$structure:=cs._Structure.new()
For each ($table; $structure.tables)
	$never_null+=$table.fields.countValues(True; "never_null")
End for each
$file:=Folder(fk data folder; *).file("__Check_Structure.json")
$file.setText(JSON Stringify($structure; *))
ALERT(String($structure.tables.length)+" tables, "+String($never_null)+" fields never_null."+Char(Carriage return)+$file.platformPath)
