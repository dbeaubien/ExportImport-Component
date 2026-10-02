// Trigger of [Spike_Keys]. DEV ONLY (ticket 01 spike).
// Counts its calls in Storage.spike.trigger_calls once a caller has created
// Storage.spike, so later tickets can tell whether triggers fired.
// Thread-safe: the compiler refuses an unsafe trigger here.
If (Storage.spike#Null)
	Use (Storage.spike)
		Storage.spike.trigger_calls:=Storage.spike.trigger_calls+1
	End use 
End if 
