(*********************************************************************************
 * Copyright: 	B&R Industrial Automation GmbH 
 * Author:    	B&R ES
 * Created:   	April 8, 2022/10:54 AM 
 * Description:	All the shuttles crossing this process point will be synched and
				initialized.
 * Mandatory: 	YES - Should be allways included before paired shuttle station 
				operations.
 *********************************************************************************)
PROGRAM _INIT
	
	(*******************************************************************)
	(******************* Process Configuration *************************)
	(*******************************************************************)
	PPAdr 	:= ADR(PP_Test); 		// <-- NAME A VALID PROCESS POINT
	SecAdr	:= ADR(SectorTrackA);	// <-- NAME A VALID SECTOR
	(*** Define in/out speed & acceleration for this process ***)
	// IN
	Speed_IN ACCESS	ADR(gSpeedEmpty); 	// <-- Bind it to Empty / Full speed global variable
	Acc_IN ACCESS ADR(gAccEmpty); 		// <-- Bind it to Empty / Full acceleration global variable
	// OUT
	Speed_OUT ACCESS ADR(gSpeedFull); 	// <-- Bind it to Empty / Full speed global variable
	Acc_OUT	ACCESS ADR(gAccFull); 		// <-- Bind it to Empty / Full acceleration global variable
	(*** SceneViewer - Shuttle color after process ***)
	Red	  := 0.0;
	Green := 1.0;
	Blue  := 0.0;
	(********************************************************************)
	
	(* Local variable to enable/disable the process *)
	CmdEnableProcess := TRUE;
	
	(* Processpointreference for Functionblocks *)
	MC_BR_TrgPointEnable_AcpTrak_0.ProcessPoint 	:= PPAdr;
	MC_BR_TrgPointGetInfo_AcpTrak_0.ProcessPoint 	:= PPAdr;
	
	(* Barrier configuration *)
	// Barrier command
	MC_BR_BarrierCommand_AcpTrak_0.ProcessPoint 					:= PPAdr;
	MC_BR_BarrierCommand_AcpTrak_0.Command 							:= mcACPTRAK_BARRIER_ADD_TICKETS;
	MC_BR_BarrierCommand_AcpTrak_0.AdvancedParameters.TicketCount 	:= 1;
	MC_BR_BarrierCommand_AcpTrak_0.Execute 							:= TRUE; (* To initialize the barrier *)
	
	(* Get process point position *)
	MC_BR_ProcPointGetInfo_AcpTrak_0.ProcessPoint   := PPAdr;
	MC_BR_ProcPointGetInfo_AcpTrak_0.Execute		:= TRUE;
	
	REPEAT 
		MC_BR_ProcPointGetInfo_AcpTrak_0();
		UNTIL 
		MC_BR_ProcPointGetInfo_AcpTrak_0.Done OR MC_BR_ProcPointGetInfo_AcpTrak_0.Error
	END_REPEAT;

	ProcPointPos 	:= MC_BR_ProcPointGetInfo_AcpTrak_0.ProcPointInfo.SectorPosition.Position;
	
	(* Counting variable *)
	CntShuttle := 1;

END_PROGRAM

PROGRAM _CYCLIC
	
	//////////////////// HIGH PRIORITY ///////////////////
	IF gTrakAsm.StatusDisabled THEN
		CntShuttle 	:= 1;
		IF (MC_BR_BarrierReadInfo_AcpTrak_0.BarrierInfo.RemainingTickets = 0) AND (MC_BR_BarrierReadInfo_AcpTrak_0.Valid) THEN
			MC_BR_BarrierCommand_AcpTrak_0.Execute := TRUE;
		END_IF
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
				ShuttleAxis[CntShuttle]	:= MC_BR_TrgPointGetInfo_AcpTrak_0.TrgPointInfo.Axis;
				Step := GET_USERDATA;
			END_IF
			
		GET_USERDATA:
			
			(* The userdata is copied on a local variable *)
			MC_BR_ShCopyUserData_AcpTrak_0.Axis 		:= ADR(ShuttleAxis[CntShuttle]);
			MC_BR_ShCopyUserData_AcpTrak_0.Execute 		:= TRUE;
			MC_BR_ShCopyUserData_AcpTrak_0.DataAddress	:= ADR(ShuttleUserData[CntShuttle]);
			MC_BR_ShCopyUserData_AcpTrak_0.DataSize 	:= SIZEOF(ShuttleUserData[CntShuttle]);
			MC_BR_ShCopyUserData_AcpTrak_0.Mode 		:= mcACPTRAK_USERDATA_GET;
			(* After copying go to the next step *)
			IF EDGEPOS(MC_BR_ShCopyUserData_AcpTrak_0.Done) THEN
				Step := GO_TO_SYNC_POS;
			END_IF
			
		GO_TO_SYNC_POS:
			
			MC_BR_RoutedMoveAbs_AcpTrak_0.Axis 	:= ADR(ShuttleAxis[CntShuttle]);
			MC_BR_RoutedMoveAbs_AcpTrak_0.Execute	:= TRUE;
			
			IF CntShuttle = 1 THEN
				MC_BR_RoutedMoveAbs_AcpTrak_0.Position := ProcPointPos + 0.05 + gProductWidth;
			ELSE
				MC_BR_RoutedMoveAbs_AcpTrak_0.Position := ProcPointPos + 0.05;
			END_IF
			
			Step := GO_TO_SYNC_POS_WAIT;
			
		GO_TO_SYNC_POS_WAIT:
			
			IF MC_BR_RoutedMoveAbs_AcpTrak_0.Done THEN
				IF CntShuttle = 1 THEN
					CntShuttle 	:= CntShuttle + 1;
					Step 		:= CREATE_CONV;
				ELSE
					Step 		:= ADD_SH_CONV;
				END_IF
			END_IF
			
		CREATE_CONV:
	
			(* Creates the convoy adding a master shuttle *)
			MC_BR_ShCreateConvoy_AcpTrak_0.Axis 		:= ADR(ShuttleAxis[1]);
			MC_BR_ShCreateConvoy_AcpTrak_0.Execute		:= TRUE;
			Step := CREATE_CONV_WAIT;
	
		CREATE_CONV_WAIT:
	
			IF MC_BR_ShCreateConvoy_AcpTrak_0.Done THEN
				MC_BR_BarrierCommand_AcpTrak_0.Execute := TRUE;
				Step := CHECK_TRIGGER;
			END_IF
			
		ADD_SH_CONV:
			
			(* Add one shuttle to the convoy *)
			MC_BR_ShMoveInConvoy_AcpTrak_0.Axis							:= ADR(ShuttleAxis[2]);
			MC_BR_ShMoveInConvoy_AcpTrak_0.Execute						:= TRUE;
			MC_BR_ShMoveInConvoy_AcpTrak_0.Parameters.ReferenceShuttle 	:= ADR(ShuttleAxis[1]);

			Step := ADD_SH_CONV_WAIT;
			
		ADD_SH_CONV_WAIT:
			
			(* Wait until shuttke us added to the convoy *)
			IF MC_BR_ShMoveInConvoy_AcpTrak_0.Done THEN
				CntShuttle 	:= 1;
				Step 		:= SET_USERDATA;
			END_IF			
			
		SET_USERDATA:
			
			(* Change color to know that shuttles are in sync. *)
			ShuttleUserData[CntShuttle].SceneColorRed 	:= Red;
			ShuttleUserData[CntShuttle].SceneColorGreen := Green;
			ShuttleUserData[CntShuttle].SceneColorBlue	:= Blue;
		
			(* After this point, the shuttle is initialized *)
			ShuttleUserData[CntShuttle].InitDone := TRUE;
			
			(* The modified userdata will be copied back on the shuttle *)
			MC_BR_ShCopyUserData_AcpTrak_0.Axis 		:= ADR(ShuttleAxis[CntShuttle]);
			MC_BR_ShCopyUserData_AcpTrak_0.Execute 		:= TRUE;
			MC_BR_ShCopyUserData_AcpTrak_0.DataAddress	:= ADR(ShuttleUserData[CntShuttle]);
			MC_BR_ShCopyUserData_AcpTrak_0.DataSize 	:= SIZEOF(ShuttleUserData[CntShuttle]);
			MC_BR_ShCopyUserData_AcpTrak_0.Mode 		:= mcACPTRAK_USERDATA_SET;
			Step := SET_USERDATA_WAIT;
		
		SET_USERDATA_WAIT:
		
			IF (MC_BR_ShCopyUserData_AcpTrak_0.Done) THEN
				(* Move the second shuttle to the next station *)
				IF (CntShuttle = 1) THEN
					CntShuttle 	:= 2;
					Step 		:= SET_USERDATA;
				ELSE (* Let the next pair of shuttles in the station *)
					CntShuttle 	:= 1;
					Step 		:= GO_TO_NEXT_STATION;
				END_IF
			END_IF
		
		GO_TO_NEXT_STATION:
		
			MC_BR_ElasticMoveVel_AcpTrak_0.Axis 	:= ADR(ShuttleAxis[1]);
			MC_BR_ElasticMoveVel_AcpTrak_0.Execute	:= TRUE;
		
			MC_BR_BarrierCommand_AcpTrak_0.Execute  := TRUE;
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
	// MC_BR_ShCreateConvoy_AcpTrak
	MC_BR_ShCreateConvoy_AcpTrak_0();
	MC_BR_ShCreateConvoy_AcpTrak_0.Execute := FALSE;
	// MC_BR_ShMoveInConvoy_AcpTrak
	MC_BR_ShMoveInConvoy_AcpTrak_0();
	MC_BR_ShMoveInConvoy_AcpTrak_0.Execute := FALSE;
	// MC_BR_BarrierCommand_AcpTrak
	MC_BR_BarrierCommand_AcpTrak_0();	
	(* When adding tickets is done, reset the execute *)
	IF EDGEPOS(MC_BR_BarrierCommand_AcpTrak_0.Done) THEN
		MC_BR_BarrierCommand_AcpTrak_0.Execute := FALSE;
	END_IF
	// MC_BR_BarrierReadInfo_AcpTrak
	MC_BR_BarrierReadInfo_AcpTrak_0.ProcessPoint := PPAdr;
	MC_BR_BarrierReadInfo_AcpTrak_0.Enable 		 := TRUE;
	MC_BR_BarrierReadInfo_AcpTrak_0();
	// MC_BR_RoutedMoveAbs_AcpTrak_0
	MC_BR_RoutedMoveAbs_AcpTrak_0.Sector 		  := SecAdr;
	MC_BR_RoutedMoveAbs_AcpTrak_0.Velocity		  := Speed_IN;
	MC_BR_RoutedMoveAbs_AcpTrak_0.Acceleration	  := Acc_IN;
	MC_BR_RoutedMoveAbs_AcpTrak_0.Deceleration	  := Acc_IN;
	MC_BR_RoutedMoveAbs_AcpTrak_0();
	MC_BR_RoutedMoveAbs_AcpTrak_0.Execute := FALSE;
	// MC_BR_ElasticMoveVel_AcpTrak_0
	MC_BR_ElasticMoveVel_AcpTrak_0.Velocity       := Speed_OUT;
	MC_BR_ElasticMoveVel_AcpTrak_0.Acceleration   := Acc_OUT;
	MC_BR_ElasticMoveVel_AcpTrak_0.Deceleration   := Acc_OUT;
	MC_BR_ElasticMoveVel_AcpTrak_0.Jerk           := 0.0;
	MC_BR_ElasticMoveVel_AcpTrak_0.Direction	  := mcDIR_POSITIVE;
	MC_BR_ElasticMoveVel_AcpTrak_0.BufferMode     := mcABORTING;
	MC_BR_ElasticMoveVel_AcpTrak_0();
	MC_BR_ElasticMoveVel_AcpTrak_0.Execute := FALSE;
	
END_PROGRAM