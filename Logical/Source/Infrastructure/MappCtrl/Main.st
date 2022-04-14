
PROGRAM _INIT
	
	MpAlarmXCore_0.MpLink 	:= ADR(gAlarmXCore);
	MpAlarmXCore_0.Enable	:= TRUE;
	MpAlarmXCore_0();
	
END_PROGRAM

PROGRAM _CYCLIC
	
	MpAlarmXCore_0();
	 
END_PROGRAM

PROGRAM _EXIT
	
	MpAlarmXCore_0.Enable := FALSE;
	MpAlarmXCore_0();
	 
END_PROGRAM

