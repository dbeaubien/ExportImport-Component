
If (Not:C34(Is compiled mode:C492)) & (Structure file:C489(*)=Structure file:C489)
	
	var $window_ref
	$window_ref:=Open form window:C675("ReleaseBuildNo_d"; Regular window:K27:1; 420; 250)
	BRING TO FRONT:C326($window_ref)
	DIALOG:C40("ReleaseBuildNo_d")
	CLOSE WINDOW:C154
	
	Log_OpenDisplayWindow
	
	ARRAY TEXT:C222($components; 0)
	COMPONENT LIST:C1001($components)
	
	If (Find in array:C230($components; "Code Analysis")>0)
		EXECUTE FORMULA:C63("CA_OnStartup")
	End if 
	
	If (Find in array:C230($components; "CodeSnippets")>0)
		EXECUTE FORMULA:C63("Snippet_ShowSelectorWindow")
	End if 
	
	If (Find in array:C230($components; "Mainfest Generator")>0)
		EXECUTE METHOD:C1007("Manifest_SetAuthor"; *; "Dani Beaubien")
		EXECUTE METHOD:C1007("Manifest_SetBuildDate"; *; Current date:C33)
		EXECUTE METHOD:C1007("Manifest_SetURL"; *; "http://openRoadDevelopment.com")
		EXECUTE METHOD:C1007("Manifest_SetCopyright"; *; "Copyright "+String:C10(Year of:C25(Current date:C33))+" Open Road Development, Inc.")
		EXECUTE METHOD:C1007("Manifest_SetVersion"; *; ExpImpComp_GetBuildNo.versionLong; True:C214)
	End if 
	
End if 