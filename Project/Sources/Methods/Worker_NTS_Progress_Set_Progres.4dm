//%attributes = {"invisible":true,"preemptive":"incapable"}
// Worker_NTS_Progress_Set_Progres (...) 
//
#DECLARE($progress_handle : Integer; $progress_ratio : Real; $subtitle : Text)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=3)

Progress SET PROGRESS($progress_handle; $progress_ratio; $subtitle)