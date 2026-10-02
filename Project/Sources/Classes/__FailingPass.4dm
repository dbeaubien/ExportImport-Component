// cs.__FailingPass
//
// DEV ONLY. A HealthCheckPass whose gate job throws (__FailingJob), for the
// failed runs of __Check_Pass and __Check_Pool.

Class extends HealthCheckPass

Class constructor($options : Object)
	Super($options)
	This._job:="__FailingJob"
