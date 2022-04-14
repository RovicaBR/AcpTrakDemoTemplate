(*interface assembly control*)

TYPE
	TrakAsmType : 	STRUCT 
		AssemblyRef : REFERENCE TO McAssemblyType; (*assembly reference - ADR(gAssembly_1)*)
		CmdPower : BOOL; (*command power on/off*)
		CmdErrorReset : BOOL; (*command error reset*)
		CmdAllShuttleMoveStop : BOOL;
		CmdAllShuttleMovePosition : BOOL;
		CmdAllShuttleMoveVelocity : BOOL;
		StatusSimulated : BOOL; (*status assembly is simulated*)
		StatusDisabled : BOOL; (*status assembly is disabled*)
		StatusReady : BOOL; (*status assembly is ready*)
		StatusHoming : BOOL; (*status assembly is homing*)
		StatusStopping : BOOL; (*status assembly is stopping*)
		StatusErrorStop : BOOL; (*status assembly is in error-stop*)
		StatusCommunicationReady : BOOL; (*status PLK communication to all segments in assembly is ready*)
		StatusReadyForPower : BOOL; (*status assembly is ready for command power-on*)
		StatusPower : BOOL; (*status assembly is power-on*)
		StatusReadyForMovement : BOOL; (*status assembly is ready to start shuttle movements*)
		MonitorSegmentsPresent : UINT; (*monitor segment present on assembly*)
		MonitorSegmentsInErrorStop : UINT; (*monitor segment in error-stop*)
		MonitorShuttlesPresent : UINT; (*monitor shuttles present on assembly*)
		MonitorShuttlesInErrorStop : UINT; (*monitor shuttles in error-stop*)
		ParaMoveSectorRef : REFERENCE TO McSectorType; (*parameter shuttle move target sector - ADR(Sector_x)*)
		ParaMovePosition : LREAL; (*parameter shuttle move target position*)
		ParaMoveVelocity : REAL; (*parameter shuttle move target velocity*)
		ParaMoveRouteVelocity : REAL; (*parameter shuttle move routing velocity*)
		ParaMoveAcceleration : REAL; (*parameter shuttle move acceleration*)
		ParaMoveDeceleration : REAL; (*parameter shuttle move deceleration*)
		Segment : ARRAY[1..TRAK_MAX_SEGMENT]OF TrakAsmSegmentType;
		Shuttle : ARRAY[1..TRAK_MAX_SHUTTLE]OF TrakAsmShuttleType; (*shuttle information*)
	END_STRUCT;
	TrakAsmShuttleType : 	STRUCT 
		Valid : BOOL; (*shuttledata valid*)
		Axis : McAxisType; (*McAxis of shuttle*)
		ID : UDINT; (*shuttle ID as displayed in logger and SceneViewer - TODO*)
		ActSectorType : McAcpTrakSecTypeEnum; (*shuttle current sector type*)
		ActSector : STRING[32]; (*shuttle current sector*)
		ActPosition : LREAL; (*shuttle position on sector*)
		ActVelocity : REAL; (*shuttle velocity on sector*)
		TotalMoveDistance : LREAL; (*shuttle total moved distance*)
		StatusStandStill : BOOL; (*shuttle is in state Standstill*)
		StatusStopping : BOOL; (*shuttle is in state Stopping*)
		StatusErrorStop : BOOL; (*shuttle is in state Errorstop*)
		StatusDiscreteMotion : BOOL; (*shuttle is in state DiscreteMotion*)
		StatusContinuousMotion : BOOL; (*shuttle is in state ContinuousMotion*)
		StatusSynchronizedMotion : BOOL; (*shuttle is in state SynchronizedMotion*)
	END_STRUCT;
	TrakAsmSegmentType : 	STRUCT 
		Valid : BOOL;
		Segment : McSegmentType;
		StatusDisabled : BOOL;
		StatusReady : BOOL;
		StatusStopping : BOOL;
		StatusErrorStop : BOOL;
		StatusShuttlesInError : BOOL;
	END_STRUCT;
END_TYPE

(*shuttle UserData structure - adapt to your application*)

TYPE
	TrakShuttleUserDataType : 	STRUCT 
		SceneColorRed : REAL; (*do not change: SceneViewer shuttle colour red*)
		SceneColorGreen : REAL; (*do not change: SceneViewer shuttle colour green*)
		SceneColorBlue : REAL; (*do not change: SceneViewer shuttle colour blue*)
		SceneText : STRING[31]; (*do not change: SceneViewer shuttle text*)
		Test : USINT; (*do not change: for use in TrakTest task*)
		ID : UINT; (*shuttle ID*)
		InitDone : BOOL; (*example: product weight*)
	END_STRUCT;
END_TYPE
