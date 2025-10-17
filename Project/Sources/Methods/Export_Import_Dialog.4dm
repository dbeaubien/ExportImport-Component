//%attributes = {"shared":true,"preemptive":"incapable"}
// Export_Import_Dialog () 
//
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=0)

var $proc_id : Integer
$proc_id:=Process number:C372(Current method name:C684)
If ($proc_id=0)
	$proc_id:=New process:C317(Current method name:C684; 0; Current method name:C684)
	return 
End if 
If ($proc_id#0) && ($proc_id#Current process:C322)
	BRING TO FRONT:C326($proc_id)
	return 
End if 

var $form_data : Object
$form_data:={}

var $window_ref
$window_ref:=Open form window:C675("Main"; Plain form window:K39:10; *)
BRING TO FRONT:C326($window_ref)
DIALOG:C40("Main"; $form_data)
CLOSE WINDOW:C154

