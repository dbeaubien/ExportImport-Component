//%attributes = {}
// Dialog_SelectTables (title) : selected_table_list
//
#DECLARE($title : Text; $table_list : Collection)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=2)

var $form_data : Object
$form_data:={\
title: $title; \
table_list: $table_list}

var $window_ref
$window_ref:=Open form window:C675("Table_Selector"; Sheet form window:K39:12; *)
BRING TO FRONT:C326($window_ref)
DIALOG:C40("Table_Selector"; $form_data)
CLOSE WINDOW:C154

