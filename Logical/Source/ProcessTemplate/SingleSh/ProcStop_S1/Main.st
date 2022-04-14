(*********************************************************************************
 * Copyright: 	B&R Industrial Automation GmbH 
 * Author:    	B&R ES
 * Created:   	April 8, 2022/10:54 AM 
 * Description:	A single shuttle will be stopped a predefined time in the process
				station.
 * Mandatory: 	NO
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
	(*** Define Wait Time (ms) ***)
	WaitTime := 500;
	(*** Define stop distance for the shuttles ***)
	DistTravelled	:= 0.33;
	(*** Define if it is a release station ***)
	ReleaseSts := FALSE;
	(*** SceneViewer - Shuttle color after process ***)
	Red	  := 0.02;
	Green := 0.77;
	Blue  := 0.21;
	(********************************************************************)

	CmdEnableProcess 	:= TRUE;
	cmdFreeShuttles		:= TRUE;
	Step 				:= CHECK_TRIGGER;
	
	MC_BR_ProcPointGetInfo_AcpTrak_0.ProcessPoint   := PPAdr; 
	MC_BR_ProcPointGetInfo_AcpTrak_0.Execute		:= TRUE;
	
	REPEAT 
		MC_BR_ProcPointGetInfo_AcpTrak_0();
	UNTIL 
		MC_BR_ProcPointGetInfo_AcpTrak_0.Done OR MC_BR_ProcPointGetInfo_AcpTrak_0.Error
	END_REPEAT;

	ProcPointPos 	:= MC_BR_ProcPointGetInfo_AcpTrak_0.ProcPointInfo.SectorPosition.Position;
	
END_PROGRAM

PROGRAM _CYCLIC

	///////////////// HIGH PRIORITY /////////////////
	(* reset process sequence if assembly is disabled *)
	IF EDGEPOS(gTrakAsm.StatusDisabled) THEN
		TON_0.IN		:= FALSE;
		cmdFreeShuttles	:= (MC_BR_BarrierReadInfo_AcpTrak_0.BarrierInfo.RemainingTickets = 0);
		Step 			:= CHECK_TRIGGER;
	END_IF
	
	///////////// BARRIER FUNCTIONALITY /////////////
	(* this state machine is developed in such a way that allows to enable/disable the station without having to stop *)
	CASE sTickets OF 
		ENABLE_BARRIER: 
			MC_BR_BarrierCommand_AcpTrak_0.ProcessPoint := PPAdr; 
			IF CmdEnableProcess THEN
				MC_BR_BarrierCommand_AcpTrak_0.Command := mcACPTRAK_BARRIER_CLOSE; 
			ELSE
				MC_BR_BarrierCommand_AcpTrak_0.Command := mcACPTRAK_BARRIER_OPEN;
			END_IF
			MC_BR_BarrierCommand_AcpTrak_0.Execute := TRUE; 
			IF (MC_BR_BarrierCommand_AcpTrak_0.Done) THEN 
				MC_BR_BarrierCommand_AcpTrak_0.Execute := FALSE;
				IF CmdEnableProcess THEN
					sTickets := FREE_SHUTTLES;
				ELSE
					sTickets := OPENED_BARRIER;
				END_IF
			END_IF
		OPENED_BARRIER:
			IF EDGEPOS(CmdEnableProcess) THEN
				cmdFreeShuttles := (MC_BR_BarrierReadInfo_AcpTrak_0.BarrierInfo.RemainingTickets = 0);
				sTickets 		:= ENABLE_BARRIER;
			END_IF
		FREE_SHUTTLES: 
			IF cmdFreeShuttles THEN 
				MC_BR_BarrierCommand_AcpTrak_0.Command 							:= mcACPTRAK_BARRIER_ADD_TICKETS; 
				MC_BR_BarrierCommand_AcpTrak_0.AdvancedParameters.TicketCount 	:= 1; 
				MC_BR_BarrierCommand_AcpTrak_0.Execute 							:= TRUE; 
				IF (MC_BR_BarrierCommand_AcpTrak_0.Done) THEN 
					MC_BR_BarrierCommand_AcpTrak_0.Execute := FALSE; 
					cmdFreeShuttles := FALSE; 
				END_IF 
			END_IF
			IF EDGENEG(CmdEnableProcess) THEN
				sTickets := ENABLE_BARRIER;
			END_IF	
	END_CASE 
	
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
				ShuttleAxis := MC_BR_TrgPointGetInfo_AcpTrak_0.TrgPointInfo.Axis;
				// read UserData from shuttle
				MC_BR_ShCopyUserData_AcpTrak_0.Axis         := ADR(ShuttleAxis);
				MC_BR_ShCopyUserData_AcpTrak_0.Execute      := TRUE;
				MC_BR_ShCopyUserData_AcpTrak_0.DataAddress  := ADR(ShuttleUserData);
				MC_BR_ShCopyUserData_AcpTrak_0.DataSize     := SIZEOF(ShuttleUserData);
				MC_BR_ShCopyUserData_AcpTrak_0.Mode         := mcACPTRAK_USERDATA_GET;
				Step := GET_SHUTTLE_DATA_WAIT;
			END_IF
        
			(* wait for shuttle-UserData content available *)
		GET_SHUTTLE_DATA_WAIT:
			IF(MC_BR_ShCopyUserData_AcpTrak_0.Done)THEN
				IF ShuttleUserData.InitDone THEN
					Step 			:= GO_TO_PROCESS_STATION;
				ELSE
					cmdFreeShuttles := (MC_BR_BarrierReadInfo_AcpTrak_0.BarrierInfo.RemainingTickets = 0);
					Step 			:= CHECK_TRIGGER;
				END_IF
			END_IF
			
		GO_TO_PROCESS_STATION:
			
			MC_BR_RoutedMoveAbs_AcpTrak_0.Axis		:= ADR(ShuttleAxis);
			MC_BR_RoutedMoveAbs_AcpTrak_0.Position 	:= ProcPointPos + DistTravelled;
			MC_BR_RoutedMoveAbs_AcpTrak_0.Execute 	:= TRUE;	
			
			Step 		:= GO_TO_PROCESS_STATION_WAIT;
			
		GO_TO_PROCESS_STATION_WAIT:
			
			IF (MC_BR_RoutedMoveAbs_AcpTrak_0.Done) THEN
				TON_0.IN 	:= TRUE;
				Step 		:= WAIT;
			END_IF
            
		WAIT:
        			            
			IF TON_0.Q THEN
				TON_0.IN 	:= FALSE;
				Step 		:= SET_SHUTTLE_DATA;
			END_IF
            
		(* write modified UserData back to shuttle *)
		SET_SHUTTLE_DATA:
			
			ShuttleUserData.SceneColorRed	:= Red;
			ShuttleUserData.SceneColorGreen	:= Green;
			ShuttleUserData.SceneColorBlue 	:= Blue;
			
			MC_BR_ShCopyUserData_AcpTrak_0.Axis         := ADR(ShuttleAxis);
			MC_BR_ShCopyUserData_AcpTrak_0.Execute      := TRUE;
			MC_BR_ShCopyUserData_AcpTrak_0.DataAddress  := ADR(ShuttleUserData);
			MC_BR_ShCopyUserData_AcpTrak_0.DataSize     := SIZEOF(ShuttleUserData);
			MC_BR_ShCopyUserData_AcpTrak_0.Mode         := mcACPTRAK_USERDATA_SET;
			Step := SET_SHUTTLE_DATA_WAIT;

		(* wait for shuttle-UserData content set *)
		SET_SHUTTLE_DATA_WAIT:
			
			IF(MC_BR_ShCopyUserData_AcpTrak_0.Done)THEN
				Step	 	:= GO_TO_NEXT_STATION;				
			END_IF
		
		(* go to next station *)
		GO_TO_NEXT_STATION:
			
			MC_BR_ElasticMoveVel_AcpTrak_0.Axis           := ADR(ShuttleAxis);
			MC_BR_ElasticMoveVel_AcpTrak_0.Execute        := TRUE;
			
			IF ReleaseSts THEN
				gProducedProduct := gProducedProduct + 1;
			END_IF
			
			cmdFreeShuttles := TRUE;
			Step 			:= CHECK_TRIGGER;
		
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
	// MC_BR_ElasticMoveVel_AcpTrak_0
	MC_BR_ElasticMoveVel_AcpTrak_0.Velocity       := Speed_OUT;
	MC_BR_ElasticMoveVel_AcpTrak_0.Acceleration   := Acc_OUT;
	MC_BR_ElasticMoveVel_AcpTrak_0.Deceleration   := Acc_OUT;
	MC_BR_ElasticMoveVel_AcpTrak_0.Jerk           := 0.0;
	MC_BR_ElasticMoveVel_AcpTrak_0.Direction	  := mcDIR_POSITIVE;
	MC_BR_ElasticMoveVel_AcpTrak_0.BufferMode     := mcABORTING;
	MC_BR_ElasticMoveVel_AcpTrak_0();
	MC_BR_ElasticMoveVel_AcpTrak_0.Execute := FALSE;
	//MC_BR_BarrierCommand_AcpTrak
	MC_BR_BarrierCommand_AcpTrak_0();
	//MC_BR_BarrierReadInfo_AcpTrak
	MC_BR_BarrierReadInfo_AcpTrak_0.ProcessPoint := PPAdr;
	MC_BR_BarrierReadInfo_AcpTrak_0.Enable		 := TRUE;
	MC_BR_BarrierReadInfo_AcpTrak_0();
	
END_PROGRAM
