//%attributes = {"invisible":true,"preemptive":"capable"}
// ExpImpComp_GetBuildNo () : buildNoObj
// 
// DESCRIPTION
//   Returns a build no object or the component.
//   For example: {"releaseYear":"2017","releaseNo":"r1","buildNo":"20170529","versionShort":"2017.r1","versionLong":"2017.r1 (build 20170529)"}
//
#DECLARE()->$build_info : Object
// ----------------------------------------------------

var $version_file : 4D:C1709.File
$version_file:=Folder:C1567(fk resources folder:K87:11).file("version.json")

If ($version_file.exists)
	var $json : Text
	$json:=$version_file.getText()
	If ($json="{@}")
		$build_info:=JSON Parse:C1218($json)
	End if 
End if 

If ($build_info=Null:C1517)
	$build_info:={}
	$build_info.releaseYear:=String:C10(Year of:C25(Current date:C33))
	$build_info.releaseNo:="r1"
	$build_info.buildNo:=Date2String(Current date:C33; "yyyymmdd")
	$version_file.setText(JSON Stringify:C1217($build_info))
End if 

$build_info.versionShort:=$build_info.releaseYear+$build_info.releaseNo
$build_info.versionLong:=$build_info.releaseYear\
+"."+$build_info.releaseNo\
+" (build "+$build_info.buildNo+")"