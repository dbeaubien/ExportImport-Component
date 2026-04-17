Case of 
	: (FORM Event:C1606.code=On Load:K2:1)
		Form:C1466.truncation_before_import:=False:C215
		Form:C1466.num_worker_processes:=3
		Form:C1466.max_export_file_size_mb:=10
		
		var $table_no; $field_no; $field_type : Integer
		Form:C1466.table_list:=[]
		Form:C1466.field_list:=[]
		For ($table_no; 1; Get last table number:C254)
			If (Not:C34(Is table number valid:C999($table_no)))
				continue
			End if 
			Form:C1466.table_list.push({\
				table_no: $table_no; \
				table_name: Table name:C256($table_no); \
				is_selected: True:C214})
			
			For ($field_no; 1; Get last field number:C255($table_no))
				If (Not:C34(Is field number valid:C1000($table_no; $field_no)))
					continue
				End if 
				
				$field_type:=Type:C295(Field:C253($table_no; $field_no)->)
				Form:C1466.field_list.push({\
					table_no: $table_no; \
					field_no: $field_no; \
					table_name: Table name:C256($table_no); \
					field_ptr: Field:C253($table_no; $field_no); \
					field_name: Field name:C257($table_no; $field_no); \
					field_type: $field_type; \
					field_type_friendly: FriendlyFieldType($field_type); \
					is_selected: False:C215})
			End for 
		End for 
		Form:C1466.table_list:=Form:C1466.table_list.orderBy("table_name")
		Form:C1466.bad_char_scan_table_list:=Form:C1466.table_list.orderBy("table_name").copy()
		
		// copy to field list to Form.bad_char_scan_ignore_field_list
		Form:C1466.bad_char_scan_ignore_field_list:=Form:C1466.field_list.query("field_type IN :1"; [Is text:K8:3; Is alpha field:K8:1]).copy()
		Form:C1466.bad_char_scan_ignore_field_list:=Form:C1466.bad_char_scan_ignore_field_list.orderBy("table_name, field_name")
		
	: (FORM Event:C1606.code=On Unload:K2:2)
		
	: (FORM Event:C1606.code=On Close Box:K2:21)
		CANCEL:C270
		
	: (FORM Event:C1606.code=On Clicked:K2:4)
		
	: (FORM Event:C1606.code=On Outside Call:K2:11)
		
	: (Process aborted:C672)
		CANCEL:C270
End case 


If (True:C214)
	
	Form:C1466.num_scan_tables_selected:=Form:C1466.bad_char_scan_table_list.query("is_selected=:1"; True:C214).length
	Case of 
		: (Form:C1466.num_scan_tables_selected=Form:C1466.bad_char_scan_table_list.length)
			Form:C1466.selected_scan_table_label:="Scan all "+String:C10(Form:C1466.num_scan_tables_selected)+" tables"
			
		: (Form:C1466.num_scan_tables_selected=0)
			Form:C1466.selected_scan_table_label:="Scan no tables"
			
		Else 
			Form:C1466.selected_scan_table_label:="Scan "+String:C10(Form:C1466.num_scan_tables_selected)+" of "+String:C10(Form:C1466.bad_char_scan_table_list.length)+" tables"
	End case 
	
	Form:C1466.num_selected_ignore_field:=Form:C1466.bad_char_scan_ignore_field_list\
		.query("is_selected=:1"; True:C214)\
		.length
	Form:C1466.selected_ignore_field_label:=String:C10(Form:C1466.num_selected_ignore_field)\
		+" alpha fields will be not scanned"
End if 


If (True:C214)
	Form:C1466.num_tables_selected:=Form:C1466.table_list.query("is_selected=:1"; True:C214).length
	Case of 
		: (Form:C1466.num_tables_selected=Form:C1466.table_list.length)
			Form:C1466.selected_table_label:="Export all "+String:C10(Form:C1466.num_tables_selected)+" tables"
			
		: (Form:C1466.num_tables_selected=0)
			Form:C1466.selected_table_label:="Export no tables"
			
		Else 
			Form:C1466.selected_table_label:="Export "+String:C10(Form:C1466.num_tables_selected)+" of "+String:C10(Form:C1466.table_list.length)+" tables"
	End case 
End if 