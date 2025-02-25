(*********************************************************************************
 * Copyright: 	B&R Industrial Automation GmbH 
 * Author:    	B&R ES
 * Created:   	April 8, 2022/10:54 AM 
 * Description:	All the shuttles crossing this process point will be unsynched.
 * Mandatory: 	NO 
 *********************************************************************************)
PROGRAM _INIT
	
	(*******************************************************************)
	(******************* Process Configuration *************************)
	(*******************************************************************)
	// Origin
	PPAdr 	:= ADR(PP_XXX); 	// <-- NAME A VALID PROCESS POINT
	// Destination
	PPDest 	:= ADR(PP_XXX);		// <-- NAME A VALID PROCESS POINT
	SecDest	:= ADR(SectorTrackA);	// <-- NAME A VALID SECTOR
	(*** Define in/out speed & acceleration for this process ***)
	// OUT
	Speed_OUT ACCESS ADR(gSpeedEmpty); 	// <-- Bind it to Empty / Full speed global variable
	Acc_OUT	ACCESS ADR(gAccEmpty); 		// <-- Bind it to Empty / Full acceleration global variable
	(*** SceneViewer - Shuttle color after process ***)
	Red	  := 1.0;
	Green := 1.0;
	Blue  := 1.0;
	(********************************************************************)
	
	(* Local variable to enable/disable the process *)
	CmdEnableProcess := TRUE;
	(* Processpointreference for Functionblocks *)
	MC_BR_TrgPointEnable_AcpTrak_0.ProcessPoint 	:= PPAdr; // <-- NAME A VALID PROCESS POINT
	MC_BR_TrgPointGetInfo_AcpTrak_0.ProcessPoint 	:= PPAdr;	// <-- NAME A VALID PROCESS POINT
	
	// Check PPDest position
	MC_BR_ProcPointGetInfo_AcpTrak_0.ProcessPoint   := PPDest; 
	MC_BR_ProcPointGetInfo_AcpTrak_0.Execute		:= TRUE;
	
	REPEAT 
		MC_BR_ProcPointGetInfo_AcpTrak_0();
		UNTIL 
		MC_BR_ProcPointGetInfo_AcpTrak_0.Done OR MC_BR_ProcPointGetInfo_AcpTrak_0.Error
	END_REPEAT;

	ProcPointPosDest 	:= MC_BR_ProcPointGetInfo_AcpTrak_0.ProcPointInfo.SectorPosition.Position;
	
END_PROGRAM

PROGRAM _CYCLIC
	
	//////////////////// HIGH PRIORITY ///////////////////
	IF gTrakAsm.StatusDisabled THEN
		Step 		:= CHECK_TRIGGER;
	END_IF
	//////////////////////////////////////////////////////
	
	CASE Step OF
		
		CHECK_TRIGGER:
			
			(* When the process is enabled and the assembly is ready, the process will be activated *)
			IF((CmdEnableProcess) AND (gTrakAsm.StatusReady))THEN
				MC_BR_TrgPointEnable_AcpTrak_0.Enable := TRUE;
				(* If a shuttle passes the triggerpoint then get the axis reference *)
				IF((MC_BR_TrgPointEnable_AcpTrak_0.Valid) AND (MC_BR_TrgPointEnable_AcpTrak_0.EventCount > 0))THEN
					MC_BR_TrgPointGetInfo_AcpTrak_0.Execute := TRUE;
				END_IF
			ELSE 
				(* Else the processpoint will be disabled *)
				MC_BR_TrgPointEnable_AcpTrak_0.Enable := FALSE;
			END_IF
			
			(* If axis reference is available, save it and go to the next step *)
			IF EDGEPOS(MC_BR_TrgPointGetInfo_AcpTrak_0.Done) THEN
			(* Save axis reference in local variable for use in step machine *)
				ShuttleAxis	:= MC_BR_TrgPointGetInfo_AcpTrak_0.TrgPointInfo.Axis;
				Step 		:= GET_USERDATA;
			END_IF
			
		GET_USERDATA:
			
			(* The userdata is copied on a local variable *)
			MC_BR_ShCopyUserData_AcpTrak_0.Axis 		:= ADR(ShuttleAxis);
			MC_BR_ShCopyUserData_AcpTrak_0.Execute 		:= TRUE;
			MC_BR_ShCopyUserData_AcpTrak_0.DataAddress	:= ADR(ShuttleUserData);
			MC_BR_ShCopyUserData_AcpTrak_0.DataSize 	:= SIZEOF(ShuttleUserData);
			MC_BR_ShCopyUserData_AcpTrak_0.Mode 		:= mcACPTRAK_USERDATA_GET;
			(* After copying go to the next step *)
			IF EDGEPOS(MC_BR_ShCopyUserData_AcpTrak_0.Done) THEN
				IF ShuttleUserData.InitDone THEN
					Step := SET_USERDATA;
				ELSE
					Step := CHECK_TRIGGER;
				END_IF
			END_IF
		
		SET_USERDATA:
			
			(* Change color to know that shuttles are in unsync. *)
			ShuttleUserData.SceneColorRed 	:= Red;
			ShuttleUserData.SceneColorGreen := Green;
			ShuttleUserData.SceneColorBlue	:= Blue;
				
			(* The modified userdata will be copied back on the shuttle *)
			MC_BR_ShCopyUserData_AcpTrak_0.Axis 		:= ADR(ShuttleAxis);
			MC_BR_ShCopyUserData_AcpTrak_0.Execute 		:= TRUE;
			MC_BR_ShCopyUserData_AcpTrak_0.DataAddress	:= ADR(ShuttleUserData);
			MC_BR_ShCopyUserData_AcpTrak_0.DataSize 	:= SIZEOF(ShuttleUserData);
			MC_BR_ShCopyUserData_AcpTrak_0.Mode 		:= mcACPTRAK_USERDATA_SET;
			Step := SET_USERDATA_WAIT;
		
		SET_USERDATA_WAIT:
		
			IF (MC_BR_ShCopyUserData_AcpTrak_0.Done) THEN
				Step := GO_TO_NEXT_STATION;
			END_IF
		
		GO_TO_NEXT_STATION:
		
			MC_BR_RoutedMoveAbs_AcpTrak_0.Axis           := ADR(ShuttleAxis);
			MC_BR_RoutedMoveAbs_AcpTrak_0.Position		 := ProcPointPosDest + 0.05;
			MC_BR_RoutedMoveAbs_AcpTrak_0.Execute        := TRUE;
		
			Step := CHECK_TRIGGER;
		
	END_CASE
		
	(*** Call all function blocks ***)
	// MC_BR_TrgPointEnable_AcpTrak
	MC_BR_TrgPointEnable_AcpTrak_0();
	// MC_BR_TrgPointGetInfo_AcpTrak
	MC_BR_TrgPointGetInfo_AcpTrak_0();
	MC_BR_TrgPointGetInfo_AcpTrak_0.Execute  := FALSE;
	// MC_BR_ShCopyUserData_AcpTrak
	MC_BR_ShCopyUserData_AcpTrak_0();
	MC_BR_ShCopyUserData_AcpTrak_0.Execute 	 := FALSE;
	// MC_BR_RoutedMoveAbs_AcpTrak_0
	MC_BR_RoutedMoveAbs_AcpTrak_0.Sector 		  := SecDest;
	MC_BR_RoutedMoveAbs_AcpTrak_0.Velocity		  := Speed_OUT;
	MC_BR_RoutedMoveAbs_AcpTrak_0.Acceleration	  := Acc_OUT;
	MC_BR_RoutedMoveAbs_AcpTrak_0.Deceleration	  := Acc_OUT;
	MC_BR_RoutedMoveAbs_AcpTrak_0();
	MC_BR_RoutedMoveAbs_AcpTrak_0.Execute := FALSE;
	
END_PROGRAM