// cs.__FailingJob
//
// DEV ONLY. A gate job that throws in its worker, for __FailingPass.

Class extends _GateJob

Class constructor($job : Object)
	Super($job)


Function _run()
	throw({errCode: 99; componentSignature: "ExportImport"; message: "forced by __FailingJob"})
