Case of 
	: (Not:C34(Form event code:C388=On Clicked:K2:4))
		
	: (Form:C1466._selected_field#Null:C1517) && (Macintosh option down:C545)
		Form:C1466._selected_field.is_selected:=Not:C34(Form:C1466._selected_field.is_selected)
		
		var $field : Object
		For each ($field; Form:C1466.field_list)
			$field.is_selected:=Form:C1466._selected_field.is_selected
		End for each 
		Form:C1466.field_list:=Form:C1466.field_list
		
		
	: (Form:C1466._selected_field#Null:C1517)
		Form:C1466._selected_field.is_selected:=Not:C34(Form:C1466._selected_field.is_selected)
		
End case 