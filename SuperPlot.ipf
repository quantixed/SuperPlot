#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include "PXPUtils"

Function SuperplotWorkflow()
	SetDataFolder root:
	
	Variable cond = 3
	Variable reps = 3
	
	Prompt cond, "How many conditions?"
	Prompt reps, "How many reps per condition?"
	DoPrompt "Specify", cond, reps
	
	if (V_flag) 
		return -1
	endif
	
	Make/O/N=5 paramWave={cond,0,0,0,reps}
	PXPUtils#MakeColorWave(cond,"colorWave")
	Superplot_Panel(cond,reps)
End

Function TemporarySuperPlotSetup(prefixRep,suffixCond)
	String prefixRep, suffixCond // lists of both, in order
	
	Wave/T tw = ListToTextWave(suffixCond,";")
	MoveWave tw, root:condWave
	Wave/T/Z condWave = root:condWave
	Variable nCond = numpnts(condWave)
	PXPUtils#MakeColorWave(nCond,"colorWave")
	Variable reps = ItemsInList(prefixRep)
	String wList, wName, allWName, allIName
	Variable mostCells = 0
	
	NewDataFolder/O root:data
	
	Variable i,j
	
	// make data folders
	for(i = 0; i < nCond; i += 1)
		NewDataFolder/O/S $("root:data:" + condWave[i])
		wList = ""
		Make/O/N=(reps)/FREE counter // counter number of measurements in each rep for this condition
		// no allowance here for missing waves i.e. unequal numbers of conditions in reps
		for(j = 0; j < reps; j += 1)
			wName = "root:" + StringFromList(j,prefixRep) + "_" + StringFromList(i,suffixCond)
			Wave w = $wName
			counter[j] = numpnts(w)
			wList += wName + ";" // add this wave to our list for concatenation
		endfor
		allWName = "sum_meas_" + StringFromList(i,suffixCond)
		Concatenate/O wList, $allWName
		allIName = "sum_index_" + StringFromList(i,suffixCond)
		Make/O/N=(sum(counter)) $allIName
		Wave iw = $allIName
		Integrate counter
		for(j = 0; j < reps; j += 1)
			if(j == 0)
				iw[0,counter[j] - 1] = j
			else
				iw[counter[j - 1],counter[j] - 1] = j
			endif
		endfor
		mostCells = max(mostCells,sum(counter))
		SetDataFolder root:
	endfor
	
	SetDataFolder root:
	CombinedSuperPlot(mostCells, reps)
End

Function CombinedSuperPlot(mostTracks, reps)
	Variable mostTracks, reps
	
	Wave/T/Z CondWave = root:condWave
	WAVE/T labelWave = CleanUpCondWave(condWave)
	Variable cond = numpnts(condWave)
	Wave/Z colorWave = root:colorWave

	KillWindow/Z SuperPlot_cond
	Display/N=SuperPlot_cond
	KillWindow/Z SuperPlot_rep
	Display/N=SuperPlot_rep
	Variable nBin, binSize, loBin, hiBin
	Variable nRow, firstRow, inBin, maxNBin
	Variable groupWidth = 0.4 // this is hard-coded for now
	Variable alphaLevel = PXPUtils#DecideOpacity(mostTracks)
	PXPUtils#MakeColorWave(reps,"colorSplitWave")
	WAVE/Z colorSplitWave = root:colorSplitWave
	MakeColorWave(reps,"colorSplitWaveA", alpha = alphaLevel)
	WAVE/Z colorSplitWaveA = root:colorSplitWaveA
	String aveName, errName
	Make/O/N=(reps,cond)/FREE collatedMat
	
	String condName, dataFolderName, wName, wList, speedName
	Variable nTracks
	Variable i, j
	
	for(i = 0; i < cond; i += 1)
		condName = condWave[i]
		// go to data folder for each master condition
		dataFolderName = "root:data:" + condName
		SetDataFolder $dataFolderName
		wName = "sum_meas_" + condName
		Wave w = $wName
		Duplicate/O/FREE w, tempW, keyW
		keyW[] = p
		Sort tempW, tempW, keyW
		nRow = numpnts(w)
		// make wave to store the counts per bin
		Make/O/N=(nRow)/I/FREE spSum_IntWave
		Make/O/N=(nRow)/FREE spSum_nWave
		Make/O/N=(nRow) spSum_xWave = i
		// make a histogram of w so that we can find the modal bin
		Histogram/B=5 w
		WAVE/Z W_Histogram
		nBin = numpnts(W_Histogram)
		binSize = deltax(W_Histogram)
		maxNbin = WaveMax(W_Histogram) + 1
		for(j = 0; j < nBin; j += 1)
			loBin = WaveMin(tempW) + (j * binSize)
			hiBin = WaveMin(tempW) + ((j + 1) * binSize)
			if(j == 0)
				loBin = 0
			elseif( j == nBin - 1)
				hiBin = inf
			endif
			spSum_IntWave[] = (tempW[p] >= loBin && tempW[p] < hiBin) ? 1 : 0
			inBin = sum(spSum_IntWave)
			// is there anything to calculate?
			if(inBin == 0)
				continue
			endif
			// yes, then 
			FindValue/I=1 spSum_IntWave
			if(V_row == -1)
				continue
			else
				firstRow = V_row
			endif
			spSum_nWave[] = (spSum_IntWave[p] == 1) ? p - firstRow : NaN
			if(mod(inBin,2) == 0)
				// change the foundRowValue to a triangular number (divisor would be inBin - 1 to get -1 to +1)
				spSum_nWave[] = (mod(spSum_nWave[p],2) == 0) ? (spSum_nWave[p] + 1) / -(maxNBin - 1) : spSum_nWave[p] / (maxNBin - 1)
			else
				// change the foundRowValue to a triangular number (divisor would be inBin to get -1 to +1)
				spSum_nWave[] = (mod(spSum_nWave[p],2) == 0) ? spSum_nWave[p] / maxNBin : (spSum_nWave[p] + 1) / -maxNBin
			endif
			// assign to xWave
			spSum_xWave[] = (numtype(spSum_nWave[p]) != 2) ? i + spSum_nWave[p] * groupWidth : spSum_xWave[p]
		endfor
		// make the order of xWave match sum_meas_*
		Sort keyW, spSum_xWave
				
		speedName = "sum_Index_" + condName
		Wave indexW = $speedName
		aveName = "spSum_" + condname + "_Ave"
		Make/O/N=(reps,4) $aveName
		Wave w1 = $aveName
		errName = ReplaceString("_Ave",AveName,"_Err")
		Make/O/N=(reps) $errName
		Wave w2 = $errName
		// set 1st column to be the x position for the averages
		w1[][0] = i
		// y values go in 2nd col and in 3rd col we put the marker types, 4th will be p
		Make/O/N=(12)/FREE markerW={19,17,16,18,23,29,26,14,8,6,5,7}
		w1[][2] = markerW[p]
		w1[][3] = p
		for(j = 0; j < reps; j += 1)
			Extract/O/FREE w, extractedValW, indexW == j
			if(DimSize(extractedValW,0) > 0)
				WaveStats/Q extractedValW
				w1[j][1] = V_Avg
				w2[j] = V_sem
			else
				w1[j][1] = NaN
				w2[j] = NaN
			endif
		endfor
		// put the means for each repeat for this group into collatedMat (to do stats)
		collatedMat[][i] = w1[p][1]
		wName = "sum_meas_" + condName
		// add to first superplot
		AppendToGraph/W=SuperPlot_cond $wName vs spSum_xWave
		ModifyGraph/W=SuperPlot_cond mode($wName)=3,marker($wName)=19
		ModifyGraph/W=SuperPlot_cond rgb($wName)=(colorWave[i][0],colorWave[i][1],colorWave[i][2],alphaLevel)
		AppendToGraph/W=SuperPlot_cond w1[][1] vs w1[][0]
		ModifyGraph/W=SuperPlot_cond rgb($aveName)=(0,0,0)
		ModifyGraph/W=SuperPlot_cond mode($aveName)=3
		ModifyGraph/W=SuperPlot_cond zmrkNum($aveName)={w1[][2]}
		// add to other superplot
		AppendToGraph/W=SuperPlot_rep $wName vs spSum_xWave
		ModifyGraph/W=SuperPlot_rep mode($wName)=3,marker($wName)=19
		ModifyGraph/W=SuperPlot_rep zColor($wName)={indexW,0,reps,cindexRGB,0,colorSplitWaveA}
		AppendToGraph/W=SuperPlot_rep w1[][1] vs w1[][0]
		ModifyGraph/W=SuperPlot_rep zColor($aveName)={w1[][3],0,reps,cindexRGB,0,colorSplitWave}
		ModifyGraph/W=SuperPlot_rep mode($aveName)=3,marker($aveName)=19,useMrkStrokeRGB($aveName)=1
		SetDataFolder root:
	endfor
	Label/W=SuperPlot_cond left "Average speed (\u03BCm/min)"
	SetAxis/A/N=1/E=1/W=SuperPlot_cond left
	Make/O/N=(numpnts(labelWave)) labelXWave = p
	ModifyGraph/W=SuperPlot_cond userticks(bottom)={labelXWave,labelWave}
	SetAxis/W=SuperPlot_cond bottom WaveMin(labelXWave) - 0.5, WaveMax(labelXWave) + 0.5
	Label/W=SuperPlot_rep left "Average speed (\u03BCm/min)"
	SetAxis/A/N=1/E=1/W=SuperPlot_rep left
	ModifyGraph/W=SuperPlot_rep userticks(bottom)={labelXWave,labelWave}
	SetAxis/W=SuperPlot_rep bottom WaveMin(labelXWave) - 0.5, WaveMax(labelXWave) + 0.5
	// do stats
	DoStatsAndLabel(collatedMat,"SuperPlot_rep")
	// add superplots to layout
//	AppendLayoutObject /W=summaryLayout graph SuperPlot_cond
//	AppendLayoutObject /W=summaryLayout graph SuperPlot_rep
End


////////////////////////////////////////////////////////////////////////
// Panel functions
////////////////////////////////////////////////////////////////////////

///	@param	cond	number of conditions - determines size of box
///	@param	reps	number of repitions - determines size of box
Function Superplot_Panel(cond, reps)
	Variable cond, reps
	
	Wave/Z colorWave = root:colorWave
	// make global text wave to store paths
	Make/T/O/N=(cond) condWave // store conditions
	Make/T/O/N=(reps,cond) waveNameWave
	
	String panelName = "WavePicker"
	KillWindow/Z $panelName
	NewPanel/N=$panelName/K=1/W=(40,40,120 + 200 * cond,150 + 30 * reps) as "Superplot Selection"
	
	// do it button
	Button DoIt,pos={20,70+30*reps},size={100,20},proc=CSPDoItButtonProc,title="Do It"

	Variable i,j
	
	for(i = 0; i < reps; i += 1)
		// row label
		DrawText/W=$panelName 10,68+i*30,num2str(i+1)
		SetDrawEnv fillfgc=(colorWave[i][0],colorWave[i][1],colorWave[i][2])
		DrawOval/W=$panelName 20,50+i*30,38,68+i*30
	endfor

	// labelling of columns
	DrawText/W=$panelName 10,30,"Reps"
	String buttonName
	
	for(i = 0; i < cond; i += 1)
		DrawText/W=$panelName 80 + 200 * i,30,CondWave[i]
		for(j = 0; j < reps; j += 1)
			buttonName = "sel_" + num2str(i) + "_" + num2str(j)
			Button $buttonName,pos={80 + 200 * i,50+j*30},size={180,20}
			MakeButtonIntoWSPopupButton(panelName, buttonName, "PopulateWaveNameWave", options=PopupWS_OptionFloat, content=WMWS_Waves)
		endfor
	endfor

End


Function CSPDoItButtonProc(ctrlName) : ButtonControl
	String ctrlName
 	
 	WAVE/T CondWave, PathWave1
	Variable okvar = 0
	
	strswitch(ctrlName)	
		case "DoIt" :
			// check MasterCondWave
//			okvar = CellMigration#WaveChecker(CondWave)
			if (okvar == -1)
				DoAlert 0, "Not all conditions have a name."
				break
			endif
//			okvar = CellMigration#NameChecker(CondWave)
			if (okvar == -1)
				DoAlert 0, "Error: Two conditions have the same name."
				break
			endif
//			okvar = CellMigration#WaveChecker(PathWave1)
			if (okvar == -1)
				Print "Note that not all conditions have a file to load."
			endif
//			LoadSuperPlotSpeedWavesFromMultiplePXPs()
			KillWindow/Z FilePicker
	endswitch	
End

Function PopulateWaveNameWave(event, wavepath, windowName, ctrlName)
	Variable event
	String wavepath, windowName, ctrlName
	
	String expr = "sel_([[:digit:]]+)_([[:digit:]]+)"
	String cond, rep
	SplitString/E=(expr) ctrlName, cond, rep
	WAVE/Z/T waveNameWave
	waveNameWave[str2num(rep)][str2num(cond)] = wavepath
End

Function CDButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	if(exists("gCDWName") != 2)
		Abort "Pick a wave to correct."
	endif
	
	SVAR CDWName = gCDWName
	Wave/Z w0 = $CDWName
	
	strswitch(ctrlName)
 
		case "CDQD"	:
//			CorrectDrift(w0,0)
			Print "Using quick and dirty method."
			break
 
		case "CDLF"	:
//			CorrectDrift(w0,1)
			Print "Using line fit method."
			break
		
		case "CDEF"	:
//			CorrectDrift(w0,2)
			Print "Using exponential fit method."
			break

	EndSwitch
	KillWindow/Z DemoPopupWaveSelectorPanel
End


////////////////////////////////////////////////////////////////////////
// Utility functions
////////////////////////////////////////////////////////////////////////

STATIC Function/WAVE CleanUpCondWave(tw)
	WAVE/T tw
	Duplicate/O tw, root:labelWave
	tw[] = CleanupName(tw[p],0)

	return root:labelWave
End

STATIC Function DoStatsAndLabel(m0,plotName)
	Wave m0
	String plotName

	String wName = NameOfWave(m0)
	Variable groups = DimSize(m0,1)
	Variable reps = DimSize(m0,0)
	if(reps < 3)
		Print "Less than three repeats, so no stats added to superplot"
		return -1
	endif
	String pStr, boxName, lookup
	Variable pVal, i
	if(groups == 2)
		Make/O/N=(reps)/FREE w0,w1
		w0[] = m0[p][0]
		w1[] = m0[p][1]
		KillWaves/Z m0
		StatsTTest/Q w0,w1
		Wave/Z W_StatsTTest
		pVal = W_StatsTTest[%P]
		pStr = FormatPValue(pVal)
		TextBox/C/N=text0/W=$plotName/F=0/A=MT/X=0.00/Y=0.00 "p = " + pStr
	elseif(groups > 2)
		SplitWave m0
		StatsDunnettTest/Q/WSTR=S_WaveNames
		WAVE/Z M_DunnettTestResults
		for(i = 1; i < groups; i += 1)
			boxName = "text" + num2str(i)
			lookup = "0_vs_" + num2str(i)
			pStr = FormatPValue(M_DunnettTestResults[%$(lookup)][%P])
			TextBox/C/N=$boxName/W=$plotName/F=0/A=MT/X=(((i - (groups/2 - 0.5))/(groups / 2))/2 * 100)/Y=0.00 pStr
		endfor
		PXPUtils#KillTheseWaves(S_WaveNames)
	else
		return -1
	endif
end

STATIC Function/S FormatPValue(pValVar)
	Variable pValVar

	String pVal = ""
	String preStr,postStr

	if(pValVar > 0.05)
		sprintf pVal, "%*.*f", 2,2, pValVar
	else
		sprintf pVal, "%*.*e", 1,1, pValVar
	endif
	if(pValVar > 0.99)
		// replace any p ~= 1 with p > 0.99
		pVal = "> 0.99"
	elseif(pValVar == 0)
		// replace any p = 0 with p < 1e-24
		pVal = "< 1e-24"
	endif
	if(StringMatch(pVal,"*e*") == 1)
		preStr = pVal[0,2]
		if(StringMatch(pVal[5],"0") == 1)
			postStr = pVal[6]
		else
			postStr = pVal[5,6]
		endif
		pVal = preStr + " x 10\S\u2212" + postStr
	endif
	return pVal
End