
Form:C1466.string_year:=String:C10(Num:C11(Form:C1466.string_year)+1)

If (Num:C11(Form:C1466.string_year)>Year of:C25(Current date:C33))
	BEEP:C151
	Form:C1466.string_year:=String:C10(Year of:C25(Current date:C33))
Else 
	Form:C1466.string_releaseNo:="r1"
End if 