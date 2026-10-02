//%attributes = {"invisible":true,"preemptive":"incapable"}
// Dialog_Progress (message)
//
// DESCRIPTION
//   Runs in the dialog's process: the passes and their jobs send it to the
//   dialog's window with CALL FORM (spec 11). message is a phase, a job's
//   progress or the run's result: see _Dialog.progress().
//
#DECLARE($message : Object)
// ----------------------------------------------------
Form.progress($message)
