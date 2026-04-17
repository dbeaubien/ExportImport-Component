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
#DECLARE($errorHandlerMethodName : Text)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

var _OnErr_MethodStack : Collection
If (_OnErr_MethodStack=Null:C1517)
	_OnErr_MethodStack:=[]
End if 

Case of 
	: ($errorHandlerMethodName#"")  // add new one to the stack
		OnErr_ClearError
		_OnErr_MethodStack.push(Method called on error:C704)
		
	: (_OnErr_MethodStack.length>0)  // remove top item from stack, get the previous one
		$errorHandlerMethodName:=_OnErr_MethodStack.pop()
		
End case 

ON ERR CALL:C155($errorHandlerMethodName)
