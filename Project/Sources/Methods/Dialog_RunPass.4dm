//%attributes = {"invisible":true,"preemptive":"incapable"}
// Dialog_RunPass (class; path; options; window; stop)
//
// DESCRIPTION
//   The dialog's coordinator process (specs 11 and 12): builds the pass
//   cs[class], attaches it to the dialog's window and Stop, runs it, then
//   sends its result to the window (_Dialog.progress()). Cooperative: the
//   coordinator needs ALTER DATABASE, selector 31 and SELECT LOG FILE. path
//   is the export set's for ImportPass and ComparePass, else "". stop is
//   the dialog's shared object.
//
#DECLARE($class : Text; $path : Text; $options : Object; $window : Integer; $stop : Object)
// ----------------------------------------------------
var $pass : cs._Pass
$pass:=($path="") ? cs[$class].new($options) : cs[$class].new($path; $options)
$pass._attach($window; $stop)
CALL FORM($window; "Dialog_Progress"; {result: $pass.run()})
