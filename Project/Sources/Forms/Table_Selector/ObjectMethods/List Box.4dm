Case of 
	: (Not:C34(Form event code:C388=On Clicked:K2:4))
		
	: (Form:C1466._selected_table#Null:C1517) && (Macintosh option down:C545)
		Form:C1466._selected_table.is_selected:=Not:C34(Form:C1466._selected_table.is_selected)
		
		var $table : Object
		For each ($table; Form:C1466.table_list)
			$table.is_selected:=Form:C1466._selected_table.is_selected
		End for each 
		Form:C1466.table_list:=Form:C1466.table_list
		
		
	: (Form:C1466._selected_table#Null:C1517)
		Form:C1466._selected_table.is_selected:=Not:C34(Form:C1466._selected_table.is_selected)
		
End case 