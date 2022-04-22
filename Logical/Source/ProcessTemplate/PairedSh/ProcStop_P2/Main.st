(*********************************************************************************
 * Copyright: 	B&R Industrial Automation GmbH 
 * Author:    	B&R ES
 * Created:   	April 8, 2022/10:54 AM 
 * Description:	Two pairs of coupled shuttles will be stopped a predefined time in the 
				process	station.
 * Mandatory: 	NO
 *********************************************************************************)
PROGRAM _INIT

	(*******************************************************************)
	(******************* Process Configuration *************************)
	(*******************************************************************)
	// Origin
	PPAdr 	:= ADR(PP_XXX); 		// <-- NAME A VALID PROCESS POINT
	SecAdr	:= ADR(SectorTrackA);	// <-- NAME A VALID SECTOR
	// Destination
	PPDest 	:= ADR(PP_XXX);			// <-- NAME A VALID PROCESS POINT
	SecDest	:= ADR(SectorTrackA);	// <-- NAME A VALID SECTOR
	(*** Define in/out speed & acceleration for this process ***)
	// IN
	Speed_IN ACCESS	ADR(gSpeedEmpty); 	// <-- Bind it to Empty / Full speed global variable
	Acc_IN ACCESS ADR(gAccEmpty); 		// <-- Bind it to Empty / Full acceleration global variable
	// OUT
	Speed_OUT ACCESS ADR(gSpeedFull); 	// <-- Bind it to Empty / Full speed global variable
	Acc_OUT	ACCESS ADR(gAccFull); 		// <-- Bind it to Empty / Full acceleration global variable
	(*** Define Wait Time (ms) ***)
	WaitTime := 500;
	(*** Define relative center point distance for the first coupled shuttles ***)
	DistTravelled	:= 0.33;
	(*** Define if it is a release station ***)
	ReleaseSts := FALSE;
	(*** SceneViewer - Shuttle color after process ***)
	Red	  := 0.02;
	Green := 0.77;
	Blue  := 0.21;
	(********************************************************************)
	
	CmdEnableProcess 	:= TRUE;
	Step 				:= CHECK_TRIGGER;
	CntShuttle 			:= 1;
	
	// Check PPAdr position
	MC_BR_ProcPointGetInfo_AcpTrak_0.ProcessPoint   := PPAdr; 
	MC_BR_ProcPointGetInfo_AcpTrak_0.Execute		:= TRUE;
	
	REPEAT 
		MC_BR_ProcPointGetInfo_AcpTrak_0();
		UNTIL 
		MC_BR_ProcPointGetInfo_AcpTrak_0.Done OR MC_BR_ProcPointGetInfo_AcpTrak_0.Error
	END_REPEAT;

	ProcPointPos 	:= MC_BR_ProcPointGetInfo_AcpTrak_0.ProcPointInfo.SectorPosition.Position;
	
	// Check PPDest position
	MC_BR_ProcPointGetInfo_AcpTrak_1.ProcessPoint   := PPDest; 
	MC_BR_ProcPointGetInfo_AcpTrak_1.Execute		:= TRUE;
	
	REPEAT 
		MC_BR_ProcPointGetInfo_AcpTrak_1();
		UNTIL 
		MC_BR_ProcPointGetInfo_AcpTrak_1.Done OR MC_BR_ProcPointGetInfo_AcpTrak_1.Error
	END_REPEAT;

	ProcPointPosDest 	:= MC_BR_ProcPointGetInfo_AcpTrak_1.ProcPointInfo.SectorPosition.Position;
	
END_PROGRAM

PROGRAM _CYCLIC

	///////////////// HIGH PRIORITY /////////////////
	(* reset process sequence if assembly is disabled *)
	IF EDGEPOS(gTrakAsm.StatusDisabled) THEN
		CntShuttle 		:= 1;
		TON_0.IN		:= FALSE;
		Step 			:= CHECK_TRIGGER;
	END_IF
	
	(***********************************************************************)
	(************************* STATE MACHINE *******************************)
	(***********************************************************************)
	
	CASE Step OF
    
		(* enable trigger and wait for one shuttle to pass *)
		CHECK_TRIGGER:
			IF((CmdEnableProcess) AND (MC_BR_AsmReadStatus_AcpTrak_0.AssemblyReady))THEN
				MC_BR_TrgPointEnable_AcpTrak_0.ProcessPoint  := PPAdr; 	
				MC_BR_TrgPointEnable_AcpTrak_0.Enable        := TRUE;
				(* shuttle passed => get axis reference *)
				IF((MC_BR_TrgPointEnable_AcpTrak_0.Valid) AND (MC_BR_TrgPointEnable_AcpTrak_0.EventCount > 0))THEN
					MC_BR_TrgPointGetInfo_AcpTrak_0.ProcessPoint  := PPAdr; 
					MC_BR_TrgPointGetInfo_AcpTrak_0.Execute       := TRUE;
					Step := GET_SHUTTLE_DATA;
				END_IF
			ELSE
				MC_BR_TrgPointEnable_AcpTrak_0.Enable  := FALSE;
			END_IF
            
            
			(* axis reference of passed shuttle available *)
			(* get shuttle-UserData *)
		GET_SHUTTLE_DATA:
			
			IF(MC_BR_TrgPointGetInfo_AcpTrak_0.Done)THEN
				ShuttleAxis[CntShuttle] := MC_BR_TrgPointGetInfo_AcpTrak_0.TrgPointInfo.Axis;
				// read UserData from shuttle
				MC_BR_ShCopyUserData_AcpTrak_0.Axis         := ADR(ShuttleAxis[CntShuttle]);
				MC_BR_ShCopyUserData_AcpTrak_0.Execute      := TRUE;
				MC_BR_ShCopyUserData_AcpTrak_0.DataAddress  := ADR(ShuttleUserData[CntShuttle]);
				MC_BR_ShCopyUserData_AcpTrak_0.DataSize     := SIZEOF(ShuttleUserData[CntShuttle]);
				MC_BR_ShCopyUserData_AcpTrak_0.Mode         := mcACPTRAK_USERDATA_GET;
				Step := GET_SHUTTLE_DATA_WAIT;
			END_IF
        
			(* wait for shuttle-UserData content available *)
		GET_SHUTTLE_DATA_WAIT:
			IF(MC_BR_ShCopyUserData_AcpTrak_0.Done)THEN
				IF ShuttleUserData[CntShuttle].InitDone THEN
					CASE CntShuttle OF
						// Master from first pair
						1:
							Step := GO_TO_PROCESS_STATION_1;
							// Slave from first pair	
						2:
							CntShuttle 	:= CntShuttle + 1;
							Step 		:= CHECK_TRIGGER;	
							// Master from second pair	
						3:
							Step := GO_TO_PROCESS_STATION_2;
							// Slave from second pair	
						4:
							Step := SET_SHUTTLE_DATA;
					END_CASE
				ELSE
					Step := CHECK_TRIGGER;
				END_IF
			END_IF
			
		GO_TO_PROCESS_STATION_1:
			
			MC_BR_RoutedMoveAbs_AcpTrak_0.Axis			:= ADR(ShuttleAxis[CntShuttle]);
			MC_BR_RoutedMoveAbs_AcpTrak_0.Position 		:= ProcPointPos + (gProductWidth/2) + DistTravelled;
			MC_BR_RoutedMoveAbs_AcpTrak_0.Execute 		:= TRUE;	
			
			CntShuttle 	:= CntShuttle + 1;
			Step 		:= CHECK_TRIGGER;
		
		GO_TO_PROCESS_STATION_2:
			
			MC_BR_RoutedMoveAbs_AcpTrak_1.Axis		:= ADR(ShuttleAxis[CntShuttle]);
			MC_BR_RoutedMoveAbs_AcpTrak_1.Position 	:= ProcPointPos + (gProductWidth/2);
			MC_BR_RoutedMoveAbs_AcpTrak_1.Execute 	:= TRUE;
			
			Step := GO_TO_PROCESS_STATION_WAIT;
			
		GO_TO_PROCESS_STATION_WAIT:
			
			MC_ReadStatus_0.Axis 	:= ADR(ShuttleAxis[1]);
			MC_ReadStatus_0.Enable	:= TRUE;
			
			MC_ReadStatus_1.Axis 	:= ADR(ShuttleAxis[3]);
			MC_ReadStatus_1.Enable	:= TRUE;
			
			IF (MC_ReadStatus_0.StandStill AND MC_ReadStatus_1.StandStill) THEN
				MC_ReadStatus_0.Enable := FALSE;
				MC_ReadStatus_1.Enable := FALSE;
				TON_0.IN 	:= TRUE;
				Step 		:= WAIT;
			END_IF
            
		WAIT:
        			            
			IF TON_0.Q THEN
				TON_0.IN 	:= FALSE;
				CntShuttle 	:= 1;
				Step 		:= SET_SHUTTLE_DATA;
			END_IF
            
			(* write modified UserData back to shuttle *)
		SET_SHUTTLE_DATA:
			
			ShuttleUserData[CntShuttle].SceneColorRed	:= Red;
			ShuttleUserData[CntShuttle].SceneColorGreen	:= Green;
			ShuttleUserData[CntShuttle].SceneColorBlue 	:= Blue;
			
			MC_BR_ShCopyUserData_AcpTrak_0.Axis         := ADR(ShuttleAxis[CntShuttle]);
			MC_BR_ShCopyUserData_AcpTrak_0.Execute      := TRUE;
			MC_BR_ShCopyUserData_AcpTrak_0.DataAddress  := ADR(ShuttleUserData[CntShuttle]);
			MC_BR_ShCopyUserData_AcpTrak_0.DataSize     := SIZEOF(ShuttleUserData[CntShuttle]);
			MC_BR_ShCopyUserData_AcpTrak_0.Mode         := mcACPTRAK_USERDATA_SET;
			Step := SET_SHUTTLE_DATA_WAIT;

			(* wait for shuttle-UserData content set *)
		SET_SHUTTLE_DATA_WAIT:
			IF(MC_BR_ShCopyUserData_AcpTrak_0.Done)THEN
				
				CASE CntShuttle OF
					1..2:
						CntShuttle 	:= CntShuttle + 1;
						Step		:= SET_SHUTTLE_DATA;	
					3:
						CntShuttle	:= CntShuttle + 1;
						Step 		:= GO_TO_NEXT_STATION;
					4:
						CntShuttle 	:= 1;
						Step	 	:= CHECK_TRIGGER;
				END_CASE
				
			END_IF
		
			(* go to next station *)
		GO_TO_NEXT_STATION:
			
			MC_BR_RoutedMoveAbs_AcpTrak_2.Axis           := ADR(ShuttleAxis[1]);
			MC_BR_RoutedMoveAbs_AcpTrak_2.Position		 := ProcPointPosDest + 0.05;
			MC_BR_RoutedMoveAbs_AcpTrak_2.Execute        := TRUE;
		
			MC_BR_RoutedMoveAbs_AcpTrak_3.Axis           := ADR(ShuttleAxis[3]);
			MC_BR_RoutedMoveAbs_AcpTrak_3.Position		 := ProcPointPosDest + 0.05;
			MC_BR_RoutedMoveAbs_AcpTrak_3.Execute        := TRUE;
			
			IF ReleaseSts THEN
				gProducedProduct := gProducedProduct + 2;
			END_IF
	
			Step := CHECK_TRIGGER;
		
	END_CASE
	
	(*** Call all function blocks ***)
	// MC_BR_AsmReadStatus_AcpTrak
	MC_BR_AsmReadStatus_AcpTrak_0.Assembly 	:= ADR(gAssembly_1);
	MC_BR_AsmReadStatus_AcpTrak_0.Enable 	:= TRUE;
	MC_BR_AsmReadStatus_AcpTrak_0();
	// MC_BR_TrgPointEnable_AcpTrak
	MC_BR_TrgPointEnable_AcpTrak_0();
	// MC_BR_TrgPointGetInfo_AcpTrak
	MC_BR_TrgPointGetInfo_AcpTrak_0();
	MC_BR_TrgPointGetInfo_AcpTrak_0.Execute := FALSE;
	// TON_0
	TON_0.PT := UDINT_TO_TIME(WaitTime); 
	TON_0();
	// MC_BR_ShCopyUserData_AcpTrak
	MC_BR_ShCopyUserData_AcpTrak_0();
	MC_BR_ShCopyUserData_AcpTrak_0.Execute := FALSE;
	// MC_BR_RoutedMoveAbs_AcpTrak_0
	MC_BR_RoutedMoveAbs_AcpTrak_0.Sector 		  := SecAdr;
	MC_BR_RoutedMoveAbs_AcpTrak_0.Velocity		  := Speed_IN;
	MC_BR_RoutedMoveAbs_AcpTrak_0.Acceleration	  := Acc_IN;
	MC_BR_RoutedMoveAbs_AcpTrak_0.Deceleration	  := Acc_IN;
	MC_BR_RoutedMoveAbs_AcpTrak_0();
	MC_BR_RoutedMoveAbs_AcpTrak_0.Execute := FALSE;
	// MC_BR_RoutedMoveAbs_AcpTrak_1
	MC_BR_RoutedMoveAbs_AcpTrak_1.Sector 		  := SecAdr;
	MC_BR_RoutedMoveAbs_AcpTrak_1.Velocity		  := Speed_IN;
	MC_BR_RoutedMoveAbs_AcpTrak_1.Acceleration	  := Acc_IN;
	MC_BR_RoutedMoveAbs_AcpTrak_1.Deceleration	  := Acc_IN;
	MC_BR_RoutedMoveAbs_AcpTrak_1();
	MC_BR_RoutedMoveAbs_AcpTrak_1.Execute := FALSE;
	// MC_BR_RoutedMoveAbs_AcpTrak_2
	MC_BR_RoutedMoveAbs_AcpTrak_2.Sector 		  := SecAdr;
	MC_BR_RoutedMoveAbs_AcpTrak_2.Velocity		  := Speed_OUT;
	MC_BR_RoutedMoveAbs_AcpTrak_2.Acceleration	  := Acc_OUT;
	MC_BR_RoutedMoveAbs_AcpTrak_2.Deceleration	  := Acc_OUT;
	MC_BR_RoutedMoveAbs_AcpTrak_2();
	MC_BR_RoutedMoveAbs_AcpTrak_2.Execute := FALSE;
	// MC_BR_RoutedMoveAbs_AcpTrak_3
	MC_BR_RoutedMoveAbs_AcpTrak_3.Sector 		  := SecAdr;
	MC_BR_RoutedMoveAbs_AcpTrak_3.Velocity		  := Speed_OUT;
	MC_BR_RoutedMoveAbs_AcpTrak_3.Acceleration	  := Acc_OUT;
	MC_BR_RoutedMoveAbs_AcpTrak_3.Deceleration	  := Acc_OUT;
	MC_BR_RoutedMoveAbs_AcpTrak_3();
	MC_BR_RoutedMoveAbs_AcpTrak_3.Execute := FALSE;
	// MC_ReadStatus
	MC_ReadStatus_0();
	MC_ReadStatus_1();
	
END_PROGRAM
