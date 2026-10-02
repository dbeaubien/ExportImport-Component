//%attributes = {"shared":true,"preemptive":"incapable"}
// Export_Import_Dialog ()
//
// DESCRIPTION
//   Opens the Main dialog (spec 11) in its own process, once: a second call
//   brings it to the front. Its form data is a cs._Dialog.
//
// ----------------------------------------------------
ASSERT(Count parameters=0)

var $process; $window : Integer
$process:=Process number(Current method name)
Case of
	: ($process=0)
		$process:=New process(Current method name; 0; Current method name)
	: ($process#Current process)
		BRING TO FRONT($process)
	Else
		$window:=Open form window("Main"; Plain form window; *)
		DIALOG("Main"; cs._Dialog.new())
		CLOSE WINDOW($window)
End case
