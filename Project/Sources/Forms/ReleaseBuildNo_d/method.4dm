
Case of 
	: (Form event code:C388=On Load:K2:1)
		// Code to set values is in the "Revert" button
		
		
	: (Form event code:C388=On Unload:K2:2)
		
		ExpImpComp_SetBuildNo(Form:C1466.string_year; Form:C1466.string_releaseNo; Form:C1466.string_buildNo)
		
End case 