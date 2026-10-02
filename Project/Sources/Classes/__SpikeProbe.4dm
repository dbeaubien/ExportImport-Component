// cs.__SpikeProbe
//
// DEV ONLY. Ticket 01's spike (fact 9): does an instance passed
// through CALL WORKER keep its class?

property name : Text

Class constructor($name : Text)
	This.name:=$name
	
Function hello() : Text
	return "hello "+This.name
