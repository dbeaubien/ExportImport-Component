
If (Not:C34(Is compiled mode:C492)) && (Structure file:C489(*)=Structure file:C489)
	
	var $window_ref : Integer
	$window_ref:=Open form window:C675("ReleaseBuildNo_d"; Regular window:K27:1; 420; 250)
	BRING TO FRONT:C326($window_ref)
	DIALOG:C40("ReleaseBuildNo_d")
	CLOSE WINDOW:C154
	
	Log_OpenDisplayWindow
	
	CA_OnStartup()
	Snippet_ShowSelectorWindow()
	
	Manifest_SetAuthor("Dani Beaubien")
	Manifest_SetBuildDate(Current date:C33)
	Manifest_SetURL("http://openRoadDevelopment.com")
	Manifest_SetCopyright("Copyright "+String:C10(Year of:C25(Current date:C33))+" Open Road Development, Inc.")
	Manifest_SetVersion(ExpImpComp_GetBuildNo.versionLong; True:C214)
End if 