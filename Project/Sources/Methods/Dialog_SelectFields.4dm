//%attributes = {}
// Dialog_SelectDialog_SelectFields (title; field_list)
//
#DECLARE($title : Text; $field_list : Collection)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=2)

var $form_data : Object
$form_data:={\
title: $title; \
field_list: $field_list}

var $window_ref
$window_ref:=Open form window:C675("Field_Selector"; Sheet form window:K39:12; *)
BRING TO FRONT:C326($window_ref)
DIALOG:C40("Field_Selector"; $form_data)
CLOSE WINDOW:C154
