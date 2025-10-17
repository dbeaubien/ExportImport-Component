Case of 
	: (FORM Event:C1606.code=On Load:K2:1)
		If (Form:C1466.title=Null:C1517)
			Form:C1466.title:="Field Selector"
		End if 
		OBJECT SET TITLE:C194(*; "dialog_title"; Form:C1466.title)
		
		
		
	: (FORM Event:C1606.code=On Unload:K2:2)
		
	: (FORM Event:C1606.code=On Close Box:K2:21)
		
	: (FORM Event:C1606.code=On Clicked:K2:4)
		
	: (FORM Event:C1606.code=On Outside Call:K2:11)
		
	: (Process aborted:C672)
		CANCEL:C270
End case 

Form:C1466.num_fields_selected:=Form:C1466.field_list.query("is_selected=:1"; True:C214).length
Case of 
	: (Form:C1466.num_fields_selected=0)
		Form:C1466.num_fields_selected_text:="No fields selected"
		
	: (Form:C1466.num_fields_selected=Form:C1466.field_list.length)
		Form:C1466.num_fields_selected_text:="All "+String:C10(Form:C1466.field_list.length)+" fields selected"
		
	Else 
		Form:C1466.num_fields_selected_text:=String:C10(Form:C1466.num_fields_selected)+" of "+String:C10(Form:C1466.field_list.length)+" fields selected"
		
End case 
OBJECT SET TITLE:C194(*; "numFieldsSelected"; Form:C1466.num_fields_selected_text)