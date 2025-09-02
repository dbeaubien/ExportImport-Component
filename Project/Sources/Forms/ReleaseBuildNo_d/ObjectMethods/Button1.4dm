
var $build_info : Object
$build_info:=ExpImpComp_GetBuildNo

Form:C1466.string_year:=String:C10($build_info.releaseYear)
Form:C1466.string_releaseNo:=String:C10($build_info.releaseNo)
Form:C1466.string_buildNo:=String:C10($build_info.buildNo)