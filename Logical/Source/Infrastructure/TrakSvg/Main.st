(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    	B&R ES 
 * Created:   	November 2, 2021/9:53 AM 
 * Name:		TrakSvg
 * Version:   	Tested with mappMotion 5.16.0
 * Description:	Template task to calculate the process product per minute outcome
 * Version 1.0: Generate an svgtransform string in order to monitor the current status
				of all the trak segments.
 *********************************************************************************)

PROGRAM _INIT
	
	// Possible Segment Status (copy to paper widget colorlist property)
	// colorList -> #CCCCCC,#B3FFB3,#FFFFB3,#FF9999
	// 0 -> Disabled 	(#CCCCCC)
	// 1 -> Ready		(#B3FFB3)
	// 2 -> Stopping	(#FFFFB3)
	// 3 -> ErrorStop	(#FF9999)
	
//	SvgTransform	:= '[{"select":"#Seg_A_1","fill":3}]';		
	
END_PROGRAM

PROGRAM _CYCLIC
	
	//////////////////////	
	// Open svg transform
	IF gTrakAsm.MonitorSegmentsPresent <> 0 THEN
		SvgTransform := '[';
		FOR i := 1 TO gTrakAsm.MonitorSegmentsPresent DO
			// Save index to auxiliar var
			brsitoa(i,ADR(SvgAux));
			//Build SvgTransform
			brsstrcat(ADR(SvgTransform), ADR('{"select":"#Seg_A_'));
			brsstrcat(ADR(SvgTransform), ADR(SvgAux));
			brsstrcat(ADR(SvgTransform), ADR('","fill":'));
			IF gTrakAsm.Segment[i].StatusReady THEN
				IF gTrakAsm.Segment[i].StatusShuttlesInError THEN
					IF ToggleVar THEN
						brsstrcat(ADR(SvgTransform), ADR('1},'));	
					ELSE
						brsstrcat(ADR(SvgTransform), ADR('3},'));
					END_IF
				ELSE
					brsstrcat(ADR(SvgTransform), ADR('1},'));
				END_IF
			ELSIF gTrakAsm.Segment[i].StatusStopping THEN
				brsstrcat(ADR(SvgTransform), ADR('2},'));
			ELSIF gTrakAsm.Segment[i].StatusErrorStop THEN
				brsstrcat(ADR(SvgTransform), ADR('3},'));
			ELSE
				brsstrcat(ADR(SvgTransform), ADR('0},'));
			END_IF
		END_FOR
		// Close svg transform
		brsstrcat(ADR(SvgTransform), ADR('{}]'));
	END_IF
	
	(* Blinking variable *)
	IF TON_0.Q THEN 
		TON_0.IN  := FALSE;
		ToggleVar := NOT ToggleVar;
	ELSE
		TON_0.IN  := TRUE;
	END_IF	
	
	TON_0.PT 	:= T#1s;
	TON_0();
	
END_PROGRAM

PROGRAM _EXIT
	
	 
END_PROGRAM

