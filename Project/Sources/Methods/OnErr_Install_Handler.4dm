//%attributes = {"invisible":true,"preemptive":"capable"}
// OnErr_Install_Handler ({errorHandlerMethodName})
// OnErr_Install_Handler ({text})
//
// DESCRIPTION
//   If a errorHandlerMethodName is specified, then the
//   "ON ERR CALL" method is called with that value.
//
//   If no parms are passed, then the previous handler
//   is restored.
//
C_TEXT:C284($1; $errorHandlerMethodName)  // optional
// ----------------------------------------------------
// HISTORY
//   Created by: Dani Beaubien (11/02/2018)
//   Mod by: Dani Beaubien (02/24/2020) - Convert to collections, do some extra testing
// ----------------------------------------------------

If (Asserted:C1132(Count parameters:C259<=1))
	If (Count parameters:C259=1)
		$errorHandlerMethodName:=$1
	End if 
	
	C_COLLECTION:C1488(_OnErr_MethodStack)
	If (_OnErr_MethodStack=Null:C1517)
		_OnErr_MethodStack:=New collection:C1472
	End if 
	
	Case of 
		: ($errorHandlerMethodName#"")  // add new one to the stack
			OnErr_ClearError
			_OnErr_MethodStack.push(Method called on error:C704)
			
		: (_OnErr_MethodStack.length>0)  // remove top item from stack, get the previous one
			$errorHandlerMethodName:=_OnErr_MethodStack.pop()
			
	End case 
	
	ON ERR CALL:C155($errorHandlerMethodName)
End if 