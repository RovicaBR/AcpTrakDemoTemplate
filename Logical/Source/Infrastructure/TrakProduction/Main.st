(*********************************************************************************
 * Copyright: B&R Industrial Automation GmbH 
 * Author:    	B&R ES 
 * Created:   	September 22, 2021/9:53 AM 
 * Name:		TrakProduction
 * Description:	Template task to calculate the process product per minute outcome. 
				The variable gProducedProduct should be increased in the process
				stations were a new product is produced.
 *********************************************************************************)

PROGRAM _INIT

	
	 
END_PROGRAM

PROGRAM _CYCLIC

	(***** Find how many non-zero values has the array storing the ProductionData  *****)
	NumData := 0;
	FOR i:=0 TO 5 DO
		IF ProductionData[i] > 0 THEN
			NumData := NumData + 1;
		END_IF
	END_FOR

	(***** Store the Produced Pouches in the ProductionData Array *****)
	// Start the timer
	TON_0.IN := TRUE;
	// Fill the Production Data array
	IF ((TON_0.Q) AND (gProducedProduct > 0)) THEN
		IF (NumData < 6) THEN //The array has not been filled yet
			// Regular production data
			FOR i:=0 TO 5 DO
				IF (ProductionData[i] = 0) THEN
					ProductionData[i] := gProducedProduct;	
					EXIT;
				END_IF			
			END_FOR
		ELSE
			FOR i:=0 TO 4 DO
				ProductionData[i] := ProductionData[i+1];
			END_FOR
			ProductionData[5] := gProducedProduct;
		END_IF	
		// Reset the produced pouches indicator
		gProducedProduct 	:= 0;	
		// Reset the timer
		TON_0.IN			:= FALSE;
	END_IF
	
	(***** Check the Products per Minute *****)
	CASE NumData OF
	
		1: //100%
			ProductsPerMinute := ProductionData[0]*6;		
		2: // 70% 30%
			ProductsPerMinute := (ProductionData[0]*0.3 + ProductionData[1]*0.7)*6;
		3: // 60% 30% 10%
			ProductsPerMinute := (ProductionData[0]*0.1 + ProductionData[1]*0.3 + ProductionData[2]*0.6)*6;
		4: // 55% 25% 15% 5%
			ProductsPerMinute := (ProductionData[0]*0.05 + ProductionData[1]*0.15 + ProductionData[2]*0.25 + ProductionData[3]*0.55)*6;
		5: // 55% 25% 15% 3% 2%
			ProductsPerMinute := (ProductionData[0]*0.02 + ProductionData[1]*0.03 + ProductionData[2]*0.15 + ProductionData[3]*0.25 + ProductionData[4]*0.55)*6;
		6: // 45% 25% 15% 10% 3% 2%
			ProductsPerMinute := (ProductionData[0]*0.02 + ProductionData[1]*0.03 + ProductionData[2]*0.1 + ProductionData[3]*0.15 + ProductionData[4]*0.25 + ProductionData[5]*0.45)*6;	
	END_CASE
	
	(* Mean Production calculation *)
	MTDataMean_0.Enable := gTrakAsm.CmdPower;
	MTDataMean_0.In 	:= ProductsPerMinute;
	MTDataMean_0();
	
	(***** Reset the Production Data when machine stops *****) 
	IF (NOT gTrakAsm.CmdPower) THEN
		FOR i:=0 TO 5 DO
			ProductionData[i] := 0;
		END_FOR
		ProductsPerMinute := 0;
	END_IF
	
	(***** Call the function blocks *****)
	TON_0.PT := T#10s;
	TON_0();
	 
END_PROGRAM

PROGRAM _EXIT
	
	 
END_PROGRAM

