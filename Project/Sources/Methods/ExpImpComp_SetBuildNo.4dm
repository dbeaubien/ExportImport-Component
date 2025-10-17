//%attributes = {"invisible":true,"preemptive":"capable"}
// ExpImpComp_SetBuildNo () : buildNoObj
// 
// DESCRIPTION
//   Returns a build no object or the component.
//   For example: {"releaseYear":"2017","releaseNo":"r1","buildNo":"20170529","versionShort":"2017.r1","versionLong":"2017.r1 (build 20170529)"}
//
#DECLARE($release_year : Text; $release_no : Text; $build_no : Text)
// ----------------------------------------------------

var $version_file : 4D:C1709.File
$version_file:=Folder:C1567(fk resources folder:K87:11).file("version.json")

var $build_info : Object
$build_info:=ExpImpComp_GetBuildNo

$build_info.releaseYear:=$release_year
$build_info.releaseNo:=$release_no
$build_info.buildNo:=$build_no
OB REMOVE:C1226($build_info; "versionShort")
OB REMOVE:C1226($build_info; "versionLong")

$version_file.setText(JSON Stringify:C1217($build_info))