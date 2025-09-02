
If (Form:C1466.string_releaseNo="r1")
	BEEP:C151
Else 
	Form:C1466.string_releaseNo:="r"+String:C10(Num:C11(Form:C1466.string_releaseNo)-1)
End if 