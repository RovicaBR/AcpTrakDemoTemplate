(*********************************************************************************
 * Copyright: 	B&R Industrial Automation GmbH 
 * Author:    	B&R
 * Created:   	February 1, 2018 
 * Description:	Trak assembly basic control task.
				* Assembly startup sequence
 				* ErrorStop handling
 				* Basic shuttle handling
 				* Aggregated shuttle move commands
 * Mandatory: 	YES - Should be always included.
 *********************************************************************************) 
 
PROGRAM _INIT

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// interface structure

	gTrakAsm.AssemblyRef				:= ADR(gAssembly_1);
	gTrakAsm.CmdPower					:= FALSE;
	gTrakAsm.CmdErrorReset				:= FALSE;

	gTrakAsm.CmdAllShuttleMoveStop		:= FALSE;
	gTrakAsm.CmdAllShuttleMovePosition	:= FALSE;
	gTrakAsm.CmdAllShuttleMoveVelocity	:= FALSE;
	gTrakAsm.ParaMoveSectorRef			:= ADR(SectorTrackA);
	gTrakAsm.ParaMovePosition			:= 2.0;
	gTrakAsm.ParaMoveVelocity			:= 2.0;
	gTrakAsm.ParaMoveRouteVelocity		:= 2.0;
	gTrakAsm.ParaMoveAcceleration		:= 20.0;
	gTrakAsm.ParaMoveDeceleration		:= 20.0;
	
	Step := COMMAND;

	// size of ShuttleUserData structure - this value has to be entered in ShuttleStereotype -> UserData -> Size
	SizeofShuttleUserData := SIZEOF(ShuttleUserData);
	
END_PROGRAM

PROGRAM _CYCLIC

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// global ErrorStop and ErrorReset
	IF(gTrakAsm.StatusErrorStop)THEN
		gTrakAsm.StatusReadyForMovement := FALSE;
		Step := ERROR;
	END_IF
	IF(gTrakAsm.CmdErrorReset)THEN
		gTrakAsm.CmdErrorReset := FALSE;
		MC_BR_AsmReset_AcpTrak_0.Execute := TRUE;
	END_IF


	CASE Step OF
	
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// command
		COMMAND:
			IF(gTrakAsm.CmdPower)THEN
				Step := RESET;
			END_IF
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// startup sequence

		// reset
		RESET:
			
			brsmemset(ADR(gTrakAsm.Segment), 0, SIZEOF(gTrakAsm.Segment));
			brsmemset(ADR(gTrakAsm.Shuttle), 0, SIZEOF(gTrakAsm.Shuttle));
			
			MC_BR_AsmGetSegment_AcpTrak_0.Enable := FALSE;
			MC_BR_AsmGetShuttle_AcpTrak_0.Enable := FALSE;
			
			Step := ASM_POWER_ON;	
				
		// assembly power ON
		ASM_POWER_ON:
			
			IF(gTrakAsm.StatusDisabled)THEN
				MC_BR_AsmPowerOn_AcpTrak_0.Execute := TRUE;
			END_IF
			Step := ASM_POWER_ON_WAIT;
			
		ASM_POWER_ON_WAIT:
			
			IF(gTrakAsm.StatusReady)THEN
				Step := GET_SEGMENT_INIT;
			END_IF			
		
		GET_SEGMENT_INIT:
			
			MC_BR_AsmGetSegment_AcpTrak_0.Enable 	:= TRUE;
			MC_BR_AsmGetSegment_AcpTrak_0.Next 		:= FALSE;
			CntSegment 	:= 0;
			Step 		:= GET_SEGMENT_WAIT;
			
		GET_SEGMENT:
			
			MC_BR_AsmGetSegment_AcpTrak_0.Next := TRUE;
			Step := GET_SEGMENT_WAIT;
			
		GET_SEGMENT_WAIT:
			
			IF(MC_BR_AsmGetSegment_AcpTrak_0.Error)THEN
				MC_BR_AsmGetSegment_AcpTrak_0.Enable := FALSE;
				Step := ERROR;
				
			ELSIF (MC_BR_AsmGetSegment_AcpTrak_0.Valid) THEN
				
				gTrakAsm.MonitorSegmentsPresent := MC_BR_AsmGetSegment_AcpTrak_0.TotalCount;
				
				IF(MC_BR_AsmGetSegment_AcpTrak_0.TotalCount = 0)THEN	// no segments present present
					MC_BR_AsmGetSegment_AcpTrak_0.Enable := FALSE;
					Step := ERROR;	
				ELSE
					
					CntSegment := CntSegment + 1;
					gTrakAsm.Segment[CntSegment].Segment := MC_BR_AsmGetSegment_AcpTrak_0.Segment;
					
					IF(MC_BR_AsmGetSegment_AcpTrak_0.RemainingCount = 0)THEN	// all present segments read => ok, proceed
						MC_BR_AsmGetSegment_AcpTrak_0.Enable := FALSE;
						Step := ADD_SHUTTLE_INIT;	
					ELSIF(CntSegment >= TRAK_MAX_SEGMENT)THEN					// more segments present than max configured => error
						MC_BR_AsmGetSegment_AcpTrak_0.Enable := FALSE;
						Step := ERROR;
					ELSE														// read next => positive edge on .Next flag
						MC_BR_AsmGetSegment_AcpTrak_0.Next := FALSE;
						Step := GET_SEGMENT;
					END_IF
				END_IF				
				
				
			END_IF
			
		// add shuttles (for simulation only)
		ADD_SHUTTLE_INIT:
			
			IF(gTrakAsm.StatusSimulated)THEN
				// Define the simulated position for each shuttle
				FOR i:=1 TO TRAK_MAX_SHUTTLE DO
					IF ((i < SimNumShuttle) AND (SimNumShuttle <= TRAK_MAX_SHUTTLE)) THEN
						SimShuttle[i].SectorRef := ADR(SectorTrackA);
						SimShuttle[i].Position 	:= 0.355 + UINT_TO_LREAL(SimNumShuttle - i)/10.0;
					ELSE
						SimShuttle[i].SectorRef := ADR(SectorTrackA);
						SimShuttle[i].Position 	:= 0.355;
					END_IF
				END_FOR	
				CntShuttle 	:= 0;
				Step 		:= ADD_SHUTTLE;
			ELSE
				Step := GET_SHUTTLE_INIT;
			END_IF
		
		ADD_SHUTTLE:
			
			CntShuttle := CntShuttle + 1;
			IF(CntShuttle > SimNumShuttle)THEN
				Step := GET_SHUTTLE_INIT;
			ELSIF(SimShuttle[CntShuttle].SectorRef = 0)THEN
				Step := GET_SHUTTLE_INIT;
			ELSE
				MC_BR_SecAddShuttle_AcpTrak_0.Sector		:= SimShuttle[CntShuttle].SectorRef;
				MC_BR_SecAddShuttle_AcpTrak_0.Execute		:= TRUE;
				MC_BR_SecAddShuttle_AcpTrak_0.Position		:= SimShuttle[CntShuttle].Position;
				MC_BR_SecAddShuttle_AcpTrak_0.AdvancedParameters.Velocity		:= 0.0;
				MC_BR_SecAddShuttle_AcpTrak_0.AdvancedParameters.Orientation	:= mcDIR_POSITIVE;
				Step := ADD_SHUTTLE_WAIT;
			END_IF
			
		ADD_SHUTTLE_WAIT:
			IF(MC_BR_SecAddShuttle_AcpTrak_0.Error)THEN
				Step := ERROR;

			ELSIF(MC_BR_SecAddShuttle_AcpTrak_0.Done)THEN
				Step := ADD_SHUTTLE;
			END_IF	
		
		// get all shuttles present on assembly
		GET_SHUTTLE_INIT:
			
			MC_BR_AsmGetShuttle_AcpTrak_0.Enable 	:= TRUE;
			MC_BR_AsmGetShuttle_AcpTrak_0.Next 		:= FALSE;
			CntShuttle 	:= 0;
			Step 		:= GET_SHUTTLE_WAIT;
		
		GET_SHUTTLE:
			
			MC_BR_AsmGetShuttle_AcpTrak_0.Next := TRUE;
			Step := GET_SHUTTLE_WAIT;
		
		GET_SHUTTLE_WAIT:
			
			IF(MC_BR_AsmGetShuttle_AcpTrak_0.Error)THEN
				MC_BR_AsmGetShuttle_AcpTrak_0.Enable := FALSE;
				Step := ERROR;
			
			ELSIF(MC_BR_AsmGetShuttle_AcpTrak_0.Valid)THEN
				gTrakAsm.MonitorShuttlesPresent := MC_BR_AsmGetShuttle_AcpTrak_0.TotalCount;
				
				IF(MC_BR_AsmGetShuttle_AcpTrak_0.TotalCount = 0)THEN			// no shuttles present => ok, proceed
					MC_BR_AsmGetShuttle_AcpTrak_0.Enable := FALSE;
					Step := READY;	
				ELSE
					CntShuttle := CntShuttle + 1;
					gTrakAsm.Shuttle[CntShuttle].Axis	:= MC_BR_AsmGetShuttle_AcpTrak_0.Axis;
					gTrakAsm.Shuttle[CntShuttle].ID		:= MC_BR_AsmGetShuttle_AcpTrak_0.AdditionalInfo.ShuttleID;
					
					// initialize shuttle UserData (White colour)
					ShuttleUserData.SceneColorRed	:= 1.0;
					ShuttleUserData.SceneColorGreen	:= 1.0;
					ShuttleUserData.SceneColorBlue	:= 1.0;
					ShuttleUserData.ID				:= CntShuttle;
					
					MC_BR_ShCopyUserData_AcpTrak_0.Axis			:= ADR(gTrakAsm.Shuttle[CntShuttle].Axis);
					MC_BR_ShCopyUserData_AcpTrak_0.Execute		:= TRUE;
					MC_BR_ShCopyUserData_AcpTrak_0.DataAddress	:= ADR(ShuttleUserData);
					MC_BR_ShCopyUserData_AcpTrak_0.DataSize		:= SIZEOF(ShuttleUserData);
					MC_BR_ShCopyUserData_AcpTrak_0.Mode			:= mcACPTRAK_USERDATA_SET;

					IF(MC_BR_AsmGetShuttle_AcpTrak_0.RemainingCount = 0)THEN	// all present shuttles read => ok, proceed
						MC_BR_AsmGetShuttle_AcpTrak_0.Enable := FALSE;
						Step := READY;	
					ELSIF(CntShuttle >= TRAK_MAX_SHUTTLE)THEN					// more shuttles present than max configured => error
						MC_BR_AsmGetShuttle_AcpTrak_0.Enable := FALSE;
						Step := ERROR;
					ELSE														// read next => positive edge on .Next flag
						MC_BR_AsmGetShuttle_AcpTrak_0.Next := FALSE;
						Step := GET_SHUTTLE;
					END_IF
				END_IF
			END_IF
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// assembly ErrorStop => ErrorReset required
		ERROR:
			
			gTrakAsm.CmdPower := FALSE;
			gTrakAsm.MonitorShuttlesPresent := 0;

			IF(gTrakAsm.StatusDisabled)THEN
				Step := COMMAND;
			ELSIF(gTrakAsm.StatusReady)THEN
				Step := ASM_POWER_OFF;
			END_IF			
			
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// assembly Active and ready for movement
		READY:
			
			gTrakAsm.StatusReadyForMovement := TRUE;
			IF(gTrakAsm.CmdPower = 0)THEN
				gTrakAsm.StatusReadyForMovement := FALSE;
				Step := ASM_POWER_OFF;
				
			ELSIF(gTrakAsm.CmdAllShuttleMoveStop)THEN
				gTrakAsm.CmdAllShuttleMoveStop := 0;
				CntShuttle := 0;
				Step := STOP_SHUTTLE;

			ELSIF(gTrakAsm.CmdAllShuttleMoveVelocity)THEN
				gTrakAsm.CmdAllShuttleMoveVelocity := 0;
				CntShuttle := 0;
				Step := MOVE_SHUTTLE_VELOCITY;

			ELSIF(gTrakAsm.CmdAllShuttleMovePosition)THEN
				gTrakAsm.CmdAllShuttleMovePosition := 0;
				CntShuttle := 0;
				Step := MOVE_SHUTTLE_POSITION;
			END_IF
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// assembly power OFF
		ASM_POWER_OFF:
			MC_BR_AsmPowerOff_AcpTrak_0.Execute := TRUE;
			Step := ASM_POWER_OFF_WAIT;
			
		ASM_POWER_OFF_WAIT:
			IF(gTrakAsm.StatusDisabled)THEN
				gTrakAsm.MonitorShuttlesPresent := 0;
				Step := ASM_SH_DELETE;
			END_IF
			
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// delete assembly shuttles	
		ASM_SH_DELETE:
			MC_BR_AsmDeleteShuttle_AcpTrak_0.Execute := TRUE;
			Step := ASM_SH_DELETE_WAIT;
			
		ASM_SH_DELETE_WAIT:
			IF MC_BR_AsmDeleteShuttle_AcpTrak_0.Done THEN
				gTrakAsm.MonitorShuttlesPresent := 0;
				Step := COMMAND;
			END_IF
			
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// stop all shuttles in assembly
		STOP_SHUTTLE:
			CntShuttle := CntShuttle + 1;
			IF(CntShuttle > TRAK_MAX_SHUTTLE)THEN
				Step := READY;
			ELSIF(gTrakAsm.Shuttle[CntShuttle].Valid)THEN
				MC_Stop_0.Axis			:= ADR(gTrakAsm.Shuttle[CntShuttle].Axis);
				MC_Stop_0.Execute		:= TRUE;
				MC_Stop_0.Deceleration	:= gTrakAsm.ParaMoveDeceleration;
				MC_Stop_0.Jerk			:= 0.0;
				Step := STOP_SHUTTLE_WAIT;
			END_IF

		STOP_SHUTTLE_WAIT:
			Step := STOP_SHUTTLE;
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// move all shuttles
		
		// accelerate all shuttles in assembly via the same taget position to the same velocity
		// used for startup, to accelerate all shuttles to an initial velocity in order to pass the first process-point
			
		MOVE_SHUTTLE_VELOCITY:
			CntShuttle := CntShuttle + 1;
			IF(CntShuttle > TRAK_MAX_SHUTTLE)THEN
				Step := READY;
			ELSIF(gTrakAsm.Shuttle[CntShuttle].Valid)THEN
				MC_BR_RoutedMoveVel_AcpTrak_0.Axis			:= ADR(gTrakAsm.Shuttle[CntShuttle].Axis);
				MC_BR_RoutedMoveVel_AcpTrak_0.Execute		:= TRUE;
				MC_BR_RoutedMoveVel_AcpTrak_0.Sector		:= gTrakAsm.ParaMoveSectorRef;
				MC_BR_RoutedMoveVel_AcpTrak_0.Position		:= gTrakAsm.ParaMovePosition;
				MC_BR_RoutedMoveVel_AcpTrak_0.Velocity		:= gTrakAsm.ParaMoveVelocity;
				MC_BR_RoutedMoveVel_AcpTrak_0.RouteVelocity	:= gTrakAsm.ParaMoveRouteVelocity;
				MC_BR_RoutedMoveVel_AcpTrak_0.Acceleration	:= gTrakAsm.ParaMoveAcceleration;
				MC_BR_RoutedMoveVel_AcpTrak_0.Deceleration	:= gTrakAsm.ParaMoveDeceleration;
				MC_BR_RoutedMoveVel_AcpTrak_0.Jerk			:= 0.0;
				MC_BR_RoutedMoveVel_AcpTrak_0.BufferMode	:= mcABORTING;
				MC_BR_RoutedMoveVel_AcpTrak_0.AdvancedParameters.StartDirection		:= mcDIR_UNDEFINED;
				MC_BR_RoutedMoveVel_AcpTrak_0.AdvancedParameters.EndDirection		:= mcDIR_POSITIVE;
				MC_BR_RoutedMoveVel_AcpTrak_0.AdvancedParameters.ShuttleOrientation	:= mcDIR_UNDEFINED;
				Step := MOVE_SHUTTLE_VELOCITY_WAIT;
			END_IF

		MOVE_SHUTTLE_VELOCITY_WAIT:
			Step := MOVE_SHUTTLE_VELOCITY;
				
		// move all shuttles in assembly to the same target position
		// used to move all shuttles to a start position - one shuttle will reach this position, all the others are queuing up
		MOVE_SHUTTLE_POSITION:
			CntShuttle := CntShuttle + 1;
			IF(CntShuttle > TRAK_MAX_SHUTTLE)THEN
				Step := READY;
			ELSIF(gTrakAsm.Shuttle[CntShuttle].Valid)THEN
				MC_BR_RoutedMoveAbs_AcpTrak_0.Axis			:= ADR(gTrakAsm.Shuttle[CntShuttle].Axis);
				MC_BR_RoutedMoveAbs_AcpTrak_0.Execute		:= TRUE;
				MC_BR_RoutedMoveAbs_AcpTrak_0.Sector		:= gTrakAsm.ParaMoveSectorRef;
				MC_BR_RoutedMoveAbs_AcpTrak_0.Position		:= 0.0;//gTrakAsm.ParaMovePosition;
				MC_BR_RoutedMoveAbs_AcpTrak_0.Velocity		:= gTrakAsm.ParaMoveVelocity;
				MC_BR_RoutedMoveAbs_AcpTrak_0.Acceleration	:= gTrakAsm.ParaMoveAcceleration;
				MC_BR_RoutedMoveAbs_AcpTrak_0.Deceleration	:= gTrakAsm.ParaMoveDeceleration;
				MC_BR_RoutedMoveAbs_AcpTrak_0.Jerk			:= 0.0;
				MC_BR_RoutedMoveAbs_AcpTrak_0.BufferMode	:= mcABORTING;
				MC_BR_RoutedMoveAbs_AcpTrak_0.AdvancedParameters.StartDirection		:= mcDIR_UNDEFINED;
				MC_BR_RoutedMoveAbs_AcpTrak_0.AdvancedParameters.EndDirection		:= mcDIR_POSITIVE;
				MC_BR_RoutedMoveAbs_AcpTrak_0.AdvancedParameters.ShuttleOrientation	:= mcDIR_UNDEFINED;
				Step := MOVE_SHUTTLE_POSITION_WAIT;
			END_IF

		MOVE_SHUTTLE_POSITION_WAIT:
			Step := MOVE_SHUTTLE_POSITION;		
	END_CASE
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// assembly FUBs
		
	MC_BR_AsmReset_AcpTrak_0.Assembly := gTrakAsm.AssemblyRef;
	MC_BR_AsmReset_AcpTrak_0();
	MC_BR_AsmReset_AcpTrak_0.Execute := FALSE;
	
	MC_BR_AsmPowerOn_AcpTrak_0.Assembly := gTrakAsm.AssemblyRef;
	MC_BR_AsmPowerOn_AcpTrak_0();
	MC_BR_AsmPowerOn_AcpTrak_0.Execute := FALSE;

	MC_BR_AsmPowerOff_AcpTrak_0.Assembly := gTrakAsm.AssemblyRef;
	MC_BR_AsmPowerOff_AcpTrak_0();
	MC_BR_AsmPowerOff_AcpTrak_0.Execute := FALSE;

	MC_BR_AsmGetInfo_AcpTrak_0.Assembly := gTrakAsm.AssemblyRef;
	MC_BR_AsmGetInfo_AcpTrak_0.Execute := TRUE;
	MC_BR_AsmGetInfo_AcpTrak_0();

	gTrakAsm.StatusSimulated := ((MC_BR_AsmGetInfo_AcpTrak_0.AssemblyInfo.SimulationOnPlcMode = mcACPTRAK_SIM_STATE_ON) OR DiagCpuIsSimulated() OR DiagCpuIsARsim());

	MC_BR_AsmReadStatus_AcpTrak_0.Assembly := gTrakAsm.AssemblyRef;
	MC_BR_AsmReadStatus_AcpTrak_0.Enable := TRUE;
	MC_BR_AsmReadStatus_AcpTrak_0();

	gTrakAsm.StatusDisabled		:= MC_BR_AsmReadStatus_AcpTrak_0.AssemblyDisabled;
	gTrakAsm.StatusReady		:= MC_BR_AsmReadStatus_AcpTrak_0.AssemblyReady;
	gTrakAsm.StatusHoming		:= MC_BR_AsmReadStatus_AcpTrak_0.AssemblyHoming;
	gTrakAsm.StatusStopping		:= MC_BR_AsmReadStatus_AcpTrak_0.AssemblyStopping;
	gTrakAsm.StatusErrorStop	:= MC_BR_AsmReadStatus_AcpTrak_0.AssemblyErrorStop;

	MC_BR_AsmReadInfo_AcpTrak_0.Assembly := gTrakAsm.AssemblyRef;
	MC_BR_AsmReadInfo_AcpTrak_0.Enable := TRUE;
	MC_BR_AsmReadInfo_AcpTrak_0();

	gTrakAsm.StatusCommunicationReady	:= MC_BR_AsmReadInfo_AcpTrak_0.AssemblyInfo.CommunicationReady;
	gTrakAsm.StatusReadyForPower		:= MC_BR_AsmReadInfo_AcpTrak_0.AssemblyInfo.ReadyForPowerOn;
	gTrakAsm.StatusPower				:= MC_BR_AsmReadInfo_AcpTrak_0.AssemblyInfo.PowerOn;
	gTrakAsm.MonitorShuttlesInErrorStop	:= MC_BR_AsmReadInfo_AcpTrak_0.AssemblyInfo.ShuttlesInErrorStopCount;
	gTrakAsm.MonitorSegmentsInErrorStop	:= MC_BR_AsmReadInfo_AcpTrak_0.AssemblyInfo.SegmentsInErrorStopCount;
	
	MC_BR_SecAddShuttle_AcpTrak_0();
	MC_BR_SecAddShuttle_AcpTrak_0.Execute := FALSE;
	
	MC_BR_AsmGetSegment_AcpTrak_0.Assembly := gTrakAsm.AssemblyRef;
	MC_BR_AsmGetSegment_AcpTrak_0();
	
	MC_BR_AsmGetShuttle_AcpTrak_0.Assembly := gTrakAsm.AssemblyRef;
	MC_BR_AsmGetShuttle_AcpTrak_0();

	MC_BR_AsmDeleteShuttle_AcpTrak_0.Assembly 	:= gTrakAsm.AssemblyRef;
	MC_BR_AsmDeleteShuttle_AcpTrak_0.Command	:= mcACPTRAK_SH_DELETE_ALL;
	MC_BR_AsmDeleteShuttle_AcpTrak_0();
	MC_BR_AsmDeleteShuttle_AcpTrak_0.Execute	:= FALSE;
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// segment FUBs
	
	FOR i:=1 TO TRAK_MAX_SEGMENT DO
		
		MC_BR_SegReadStatus_AcpTrak_0[i].Segment := ADR(gTrakAsm.Segment[i].Segment);
		MC_BR_SegReadStatus_AcpTrak_0[i].Enable  := (gTrakAsm.Segment[i].Segment.controlif <> 0);
		MC_BR_SegReadStatus_AcpTrak_0[i]();
		
		gTrakAsm.Segment[i].Valid := (MC_BR_SegReadStatus_AcpTrak_0[i].Valid);
		
		IF (gTrakAsm.Segment[i].Valid) THEN
			gTrakAsm.Segment[i].StatusDisabled 	:= MC_BR_SegReadStatus_AcpTrak_0[i].SegmentDisabled;
			gTrakAsm.Segment[i].StatusReady		:= MC_BR_SegReadStatus_AcpTrak_0[i].SegmentReady;
			gTrakAsm.Segment[i].StatusStopping	:= MC_BR_SegReadStatus_AcpTrak_0[i].SegmentStopping;
			gTrakAsm.Segment[i].StatusErrorStop	:= MC_BR_SegReadStatus_AcpTrak_0[i].SegmentErrorStop;
		END_IF
		
	END_FOR
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// shuttle FUBs

	FOR i:=1 TO TRAK_MAX_SHUTTLE DO
	
		MC_BR_ShReadInfo_AcpTrak_0[i].Axis		:= ADR(gTrakAsm.Shuttle[i].Axis);
		MC_BR_ShReadInfo_AcpTrak_0[i].Enable	:= (gTrakAsm.Shuttle[i].Axis.controlif <> 0);
		MC_BR_ShReadInfo_AcpTrak_0[i]();

		MC_ReadStatus_0[i].Axis		:= ADR(gTrakAsm.Shuttle[i].Axis);
		MC_ReadStatus_0[i].Enable	:= (gTrakAsm.Shuttle[i].Axis.controlif <> 0);
		MC_ReadStatus_0[i]();

		gTrakAsm.Shuttle[i].Valid := (MC_BR_ShReadInfo_AcpTrak_0[i].Valid AND MC_ReadStatus_0[i].Valid);
		IF(gTrakAsm.Shuttle[i].Valid)THEN
			gTrakAsm.Shuttle[i].ActSectorType		:= MC_BR_ShReadInfo_AcpTrak_0[i].ShuttleInfo.CurrentValues.SectorType;
			gTrakAsm.Shuttle[i].ActSector			:= MC_BR_ShReadInfo_AcpTrak_0[i].ShuttleInfo.CurrentValues.SectorName;
			gTrakAsm.Shuttle[i].ActPosition			:= MC_BR_ShReadInfo_AcpTrak_0[i].ShuttleInfo.CurrentValues.Position;
			gTrakAsm.Shuttle[i].ActVelocity			:= MC_BR_ShReadInfo_AcpTrak_0[i].ShuttleInfo.CurrentValues.Velocity;
			gTrakAsm.Shuttle[i].TotalMoveDistance	:= MC_BR_ShReadInfo_AcpTrak_0[i].ShuttleInfo.LifeCycleInfo.AbsoluteMovementDistance;
			gTrakAsm.Shuttle[i].StatusStandStill			:= MC_ReadStatus_0[i].StandStill;
			gTrakAsm.Shuttle[i].StatusStopping				:= MC_ReadStatus_0[i].Stopping;
			gTrakAsm.Shuttle[i].StatusErrorStop				:= MC_ReadStatus_0[i].ErrorStop;
			gTrakAsm.Shuttle[i].StatusDiscreteMotion		:= MC_ReadStatus_0[i].DiscreteMotion;
			gTrakAsm.Shuttle[i].StatusContinuousMotion		:= MC_ReadStatus_0[i].ContinuousMotion;
			gTrakAsm.Shuttle[i].StatusSynchronizedMotion	:= MC_ReadStatus_0[i].SynchronizedMotion;
		END_IF
		
	END_FOR
	
	MC_BR_ShCopyUserData_AcpTrak_0();
	MC_BR_ShCopyUserData_AcpTrak_0.Execute := FALSE;
	
	MC_Stop_0();
	MC_Stop_0.Execute := FALSE;
	
	MC_BR_RoutedMoveVel_AcpTrak_0();
	MC_BR_RoutedMoveVel_AcpTrak_0.Execute := FALSE;
	
	MC_BR_RoutedMoveAbs_AcpTrak_0();
	MC_BR_RoutedMoveAbs_AcpTrak_0.Execute := FALSE;

END_PROGRAM


PROGRAM _EXIT

END_PROGRAM

