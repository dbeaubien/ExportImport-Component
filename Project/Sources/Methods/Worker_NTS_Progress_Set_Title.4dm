//%attributes = {"invisible":true,"preemptive":"incapable"}
// Worker_NTS_Progress_Set_Title (...) 
//
#DECLARE($progress_handle : Integer; $title : Text; $progress_ratio : Real; $subtitle : Text)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=4)

Progress SET TITLE($progress_handle; $title; $progress_ratio; $subtitle)