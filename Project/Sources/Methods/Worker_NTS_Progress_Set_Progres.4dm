//%attributes = {"invisible":true,"preemptive":"incapable"}
// Worker_NTS_Progress_Set_Progres (...) 
//
var $1; $progHdl : Integer
var $2; $progress_ratio : Real
var $3; $subtitle : Text
// ----------------------------------------------------
// HISTORY
//   Created by: DB (09/23/2022)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=3)
$progHdl:=$1
$progress_ratio:=$2
$subtitle:=$3

Progress SET PROGRESS($progHdl; $progress_ratio; $subtitle)