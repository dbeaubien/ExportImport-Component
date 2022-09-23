//%attributes = {"invisible":true,"preemptive":"incapable"}
// Worker_NTS_Progress_Set_Title (...) 
//
var $1; $progHdl : Integer
var $2; $title : Text
var $3; $progress_ratio : Real
var $4; $subtitle : Text
// ----------------------------------------------------
// HISTORY
//   Created by: DB (09/23/2022)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=4)
$progHdl:=$1
$title:=$2
$progress_ratio:=$3
$subtitle:=$4

Progress SET TITLE($progHdl; $title; $progress_ratio; $subtitle)