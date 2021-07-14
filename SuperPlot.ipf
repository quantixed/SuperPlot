#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <PopUpWaveSelector>
#include <WaveSelectorWidget>
#include "PXPUtils"

// Make SuperPlots in IGOR Pro
// SuperPlots were described by Lord et al. (2020) J Cell Biol https://doi.org/10.1083/jcb.202001064
// This code requires data to be loaded into Igor before execution.
// The format is three 1D waves:
//		Reps - numeric - which experimental repeat the measurement comes from
//		Condition - text - which experimental condition the measurement corresponds to
//		Measurement - numeric - the measurement itself
// The naming of the waves does not matter.

////////////////////////////////////////////////////////////////////////
// Menu items
////////////////////////////////////////////////////////////////////////

Menu "Macros"
	Submenu	"SuperPlot"
		"Make SuperPlot",  SuperplotWorkflow()
	End
End

////////////////////////////////////////////////////////////////////////
// Master functions and wrappers
////////////////////////////////////////////////////////////////////////

Function SuperplotWorkflow()
	SetupSuperPlotPackage()
	String latestSuperPlotName = findLatestSuperPlotName()
	Superplot_Panel(latestSuperPlotName)
End

////////////////////////////////////////////////////////////////////////
// Main functions
////////////////////////////////////////////////////////////////////////

///	@param	repW	1D numeric wave with rep numbers
///	@param	repW	1D text wave with condition
///	@param	measW	1D numeric wave with measurements
///	@param	spName	string - superplot name
Function SuperPlotPrep(repW,condW,measW,spName)
	Wave repW
	Wave/T condW
	Wave measW
	String spName
	
	String dfPath = "root:Packages:SuperPlot:" + spName
	// this datafolder should already exist
	if(!DataFolderExists(dfPath))
		NewDataFolder/O/S $dfPath
	else
		SetDataFolder $dfPath
	endif
	
	FindDuplicates/RN=uRepW repW
	FindDuplicates/RT=uCondW condW
	Variable reps = numpnts(uRepW)
	Variable nCond = numpnts(uCondW)
	// process meas wave using unique rep/cond waves to make group
	Variable mostCells = 0
	Variable i,j
	
	for(i = 0; i < nCond; i += 1)
		// retrieve measurements for each condition (use alias for condName)
		Duplicate/O measW, $(dfPath + ":sum_meas_cond" + num2str(i))
		Wave condMeasW = $(dfPath + ":sum_meas_cond" + num2str(i))
		condMeasW[] = (CmpStr(uCondW[i], condW[p]) == 0) ? measW[p] : NaN
		// retrieve rep no. for each condition - store as "index"
		Duplicate/O repW, $(dfPath + ":sum_index_cond" + num2str(i))
		Wave condRepW = $(dfPath + ":sum_index_cond" + num2str(i))
		condRepW[] = (CmpStr(uCondW[i], condW[p]) == 0) ? repW[p] : NaN
		// delete other values
		WaveTransform zapnans condMeasW
		WaveTransform zapnans condRepW
		if(numpnts(condMeasW) != numpnts(condRepW))
			Print "Problem with data for", uCondW[i]
		endif
		mostCells = max(mostCells,numpnts(condMeasW))
		
		// because reps may be called 1,2,3 or 0,1,2 we need to reindex them from 0
		Duplicate/O condRepW, $(dfPath + ":sum_rep_cond" + num2str(i))
		Wave reIndexW = $(dfPath + ":sum_rep_cond" + num2str(i))
		for(j = 0; j < reps; j += 1)
			reIndexW[] = (condRepW[p] == uRepW[j]) ? j : reIndexW[p]
		endfor
		
	endfor
	
	Variable groupWidth = 0.4 // this is hard-coded for now
	Variable alphaLevel = PXPUtils#DecideOpacity(mostCells)
	// colorwave needs to be specific to this df (root: is added by function)
	PXPUtils#MakeColorWave(reps,"Packages:SuperPlot:" + spName + ":colorSplitWave")
	PXPUtils#MakeColorWave(reps,"Packages:SuperPlot:" + spName + ":colorSplitWaveA", alpha = alphaLevel)
	
	// we will stay in dfpath and make the superplot
	SuperPlotEngine(mostCells, reps, nCond, groupWidth, alphaLevel, 1, spName)
End

///	@param	maxCells	variable - the most measurements in any group
///	@param	nRep	variable - number of repitions
///	@param	nCond	variable - number of conditions
///	@param	groupWidth	variable - how wide the points spread on the x-axis
///	@param	alphaLevel	variable - level of opacity for points
///	@param	addBars	variable - 0 or 1 to indicate addition of bars
/// @param	spName	string - superplot name relates to dfname and plotname
Function SuperPlotEngine(maxCells, nRep, nCond, groupWidth, alphaLevel, addBars, spName)
	Variable maxCells, nRep, nCond, groupWidth, alphaLevel, addBars
	String spName
	
	String dfPath = "root:Packages:SuperPlot:" + spName
	if(CmpStr(GetDataFolder(0),dfPath) != 0)
		SetDataFolder $dfPath
	endif
	
	WAVE/T/Z uCondW
	Duplicate/O uCondW, labelWave
	WAVE/Z uRepW,colorSplitWave,colorSplitWaveA
	
	String plotName = "p_" + spName
	KillWindow/Z $plotName
	Display/N=$plotName
	Variable nBin, binSize, loBin, hiBin
	Variable nRow, firstRow, inBin, maxNBin
	String aveName, errName
	// a 2D wave to capture averages
	Make/O/N=(nRep,nCond)/FREE collatedMat
	
	String wName, xWName, wList, speedName
	
	Variable nTracks
	Variable i, j
	
	for(i = 0; i < nCond; i += 1)
		wName = "sum_meas_cond" + num2str(i)
		Wave w = $wName
		Duplicate/O/FREE w, tempW, keyW
		keyW[] = p
		Sort tempW, tempW, keyW
		nRow = numpnts(w)
		// make wave to store the counts per bin
		Make/O/N=(nRow)/I/FREE spSum_IntWave
		Make/O/N=(nRow)/FREE spSum_nWave
		xWName = "spSum_cond" + num2str(i) + "_xWave"
		Make/O/N=(nRow) $xWName = i
		Wave xW = $xWName
		// make a histogram of w so that we can find the modal bin
		// We use Freedman-Diaconis method - this (together with width controls splay)
		Histogram/B=5 w
		WAVE/Z W_Histogram
		nBin = numpnts(W_Histogram)
		binSize = deltax(W_Histogram)
		maxNbin = WaveMax(W_Histogram) + 1
		KillWaves W_Histogram
		
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
			xW[] = (numtype(spSum_nWave[p]) != 2) ? i + spSum_nWave[p] * groupWidth : xW[p]
		endfor
		// make the order of xWave match sum_meas_*
		Sort keyW, xW
		// make reference to the index wave we made previously
		Wave indexW = $("sum_index_cond" + num2str(i)) // original rep coding from data
		Wave reIndexW = $("sum_rep_cond" + num2str(i)) // alias based on p (or number of reps 0-based)
		
		aveName = "spSum_cond" + num2str(i) + "_Ave"
		Make/O/N=(nRep,3) $aveName
		Wave aveW = $aveName
		// set 1st column to be the x position for the averages
		aveW[][0] = i
		// y values go in 2nd col and in 3rd col is p (corresponds to reps)
		aveW[][2] = p
		
		for(j = 0; j < nRep; j += 1)
			Extract/O/FREE w, extractedValW, indexW == uRepW[j]
			if(DimSize(extractedValW,0) > 0)
				WaveStats/Q extractedValW
				aveW[j][1] = V_Avg
			else
				aveW[j][1] = NaN
			endif
		endfor
		// put the means for each repeat for this group into collatedMat (to do stats)
		collatedMat[][i] = aveW[p][1]

		// build superplot
		// add points
		AppendToGraph/W=$plotName $wName vs xW
		ModifyGraph/W=$plotName mode($wName)=3,marker($wName)=19
		ModifyGraph/W=$plotName zColor($wName)={reIndexW,0,nRep,cindexRGB,0,colorSplitWaveA}
		if(addBars == 1)
			MakeAndAddBarsForPlot(aveW,plotName,i,groupWidth)
		endif
		// add averages per rep/group
		AppendToGraph/W=$plotName aveW[][1] vs aveW[][0]
		ModifyGraph/W=$plotName zColor($aveName)={aveW[][2],0,nRep,cindexRGB,0,colorSplitWave}
		ModifyGraph/W=$plotName mode($aveName)=3,marker($aveName)=19,useMrkStrokeRGB($aveName)=1
	endfor
	
	Make/O/N=(numpnts(labelWave)) labelXWave = p
	ModifyGraph/W=$plotName userticks(bottom)={labelXWave,labelWave}
	Label/W=$plotName left "Measurement"
	SetAxis/A/N=1/E=1/W=$plotName left
	ModifyGraph/W=$plotName userticks(bottom)={labelXWave,labelWave}
	SetAxis/W=$plotName bottom WaveMin(labelXWave) - 0.5, WaveMax(labelXWave) + 0.5
	// do stats
	DoStatsAndLabel(collatedMat,plotName)
	
	SetDataFolder root:
End

///	@param	aveW	wave containing the averages of measurements per rep for one conditions
///	@param	plotName	string - graph to add the error bar to
///	@param	condNum	variable relates to condition number and x position
///	@param	width	variable - called groupwidth above
STATIC Function MakeAndAddBarsForPlot(aveW,plotName,condNum,width)
	Wave aveW
	String plotName
	Variable condNum, width
	// 2D wave xy coords
	String hbName = "spSum_cond" + num2str(condNum) + "_hBar"
	Make/O/N=(2,2) $hbName
	Wave hb = $hbName
	String vbName = "spSum_cond" + num2str(condNum) + "_vBar"
	Make/O/N=(2,2) $vbName
	Wave vb = $vbName
	String vcName = "spSum_cond" + num2str(condNum) + "_vCap"
	Make/O/N=(5,2) $vcName
	Wave vc = $vcName

	WaveStats/RMD=[][1]/Q aveW // not sensitive to NaNs
	hb[][1] = V_avg
	hb[0][0] = condNum - width / 2
	hb[1][0] = condNum + width / 2
	vb[][0] = condNum
	vb[0][1] = V_avg - V_sdev
	vb[1][1] = V_avg + V_sdev
	vc[0,1][1] = vb[0][1]
	vc[2][1] = NaN
	vc[3,4][1] = vb[1][1]
	vc[0][0] = condNum - width / 4
	vc[1][0] = condNum + width / 4
	vc[2][0] = NaN
	vc[3][0] = condNum - width / 4
	vc[4][0] = condNum + width / 4
	AppendToGraph/W=$plotName vb[][1] vs vb[][0]
	AppendToGraph/W=$plotName vc[][1] vs vc[][0]
	AppendToGraph/W=$plotName hb[][1] vs hb[][0]
	ModifyGraph/W=$plotName rgb($vbName)=(0,0,0),rgb($vcName)=(0,0,0),rgb($hbName)=(0,0,0)
	ModifyGraph/W=$plotName lsize($hbName)=2
End


////////////////////////////////////////////////////////////////////////
// Panel functions
////////////////////////////////////////////////////////////////////////

Function Superplot_Panel(spName)
	String spName
	if(!DatafolderExists("root:Packages:SuperPlot:" + spName))
		NewDataFolder/O $("root:Packages:SuperPlot:" + spName)
	endif
	
	String panelName = "Picker_" + spName
	KillWindow/Z $panelName
	NewPanel/N=$panelName/K=1/W=(40,40,480,480) as "SuperPlot Selection"
	
	// wave selection
	DrawText/W=$panelName 10,30,"Specify waves for SuperPlot " + spName
	
	// repeat Wave
	TitleBox tb1,pos={40,60},size={115,12},title="Select wave with repeat info:",frame=0
	Button repBtn,pos={40,80},size={180,20}
	MakeButtonIntoWSPopupButton(panelName, "repBtn", "PopulateWaveNameWave", options=PopupWS_OptionFloat, content=WMWS_Waves)
	// condition Wave
	TitleBox tb2,pos={40,160},size={115,12},title="Select wave with repeat info:",frame=0
	Button condBtn,pos={40,180},size={180,20}
	MakeButtonIntoWSPopupButton(panelName, "condBtn", "PopulateWaveNameWave", options=PopupWS_OptionFloat, content=WMWS_Waves)
	// measure Wave
	TitleBox tb3,pos={40,260},size={115,12},title="Select wave with measurements:",frame=0
	Button measBtn,pos={40,280},size={180,20}
	MakeButtonIntoWSPopupButton(panelName, "measBtn", "PopulateWaveNameWave", options=PopupWS_OptionFloat, content=WMWS_Waves)
	
	// do it button
	Button DoIt,pos={330,400},size={100,20},proc=SPButtonProc,title="Do It"
End

// the function is called by the popup buttons in the panel
Function PopulateWaveNameWave(event, wavepath, windowName, ctrlName)
	Variable event
	String wavepath, windowName, ctrlName
	
	String wName = "root:Packages:SuperPlot:" + ReplaceString("picker_",windowName,"") + ":waveNameWave"
	WAVE/Z/T waveNameWave = $wName
	if(!WaveExists(waveNameWave))
		Make/O/N=(3)/T $wName
		WAVE/Z/T waveNameWave = $wName
	endif
	
	strswitch(ctrlName)	
		case "repBtn" :
			waveNameWave[0] = wavepath
			break
		case "condBtn" :
			waveNameWave[1] = wavepath
			break
		case "measBtn" :
			waveNameWave[2] = wavepath
			break
	endswitch
End

Function SPButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	String spName = ReplaceString("picker_",ba.win,"")
	Wave/Z/T waveNameWave = $("root:Packages:SuperPlot:" + spName + ":waveNameWave")
	
	switch(ba.eventCode)
		case 2 :
			if(CmpStr(ba.ctrlName,"DoIt") == 0)
				if(checkWaveNameWave(waveNameWave) == 0)
					KillWindow/Z $(ba.win)
					Wave w0 = $(waveNameWave[0])
					Wave/T w1 = $(waveNameWave[1])
					Wave w2 = $(waveNameWave[2])
					SuperPlotPrep(w0,w1,w2,spName)
//					SuperPlotEngine(maxCells, nRep, nCond, groupWidth, alphaLevel, addBars, spName)
					return 0
				else
					return -1
				endif
			else
				return -1
			endif
		case -1:
			break
	endswitch
	
	return 0
End


////////////////////////////////////////////////////////////////////////
// Utility functions
////////////////////////////////////////////////////////////////////////

STATIC Function SetupSuperPlotPackage()
	if(!DatafolderExists("root:Packages:SuperPlot"))
		NewDataFolder/O root:Packages
		NewDataFolder/O root:Packages:SuperPlot
	endif
End

STATIC Function/S findLatestSuperPlotName()
	String spDFName
	Variable i = 0
	do
		spDFName = "sp" + num2str(i)
		if(!DatafolderExists("root:Packages:SuperPlot:" + spDFName))
			break
		else
			i += 1
		endif
	while (i < 10) // limit of ten superplots
	
	return spDFName
End

STATIC Function checkWaveNameWave(tw)
	WAVE/T tw
	if(strlen(tw[0]) == 0 || strlen(tw[1]) == 0 || strlen(tw[2]) == 0)
		DoAlert 0, "Specify all three waves"
		return -1
	elseif(CmpStr(tw[0],tw[1]) * CmpStr(tw[0],tw[2]) * CmpStr(tw[1],tw[2]) == 0)
		DoAlert 0, "One or more input waves are the same"
		return -1
	else
		return 0
	endif
	// other error
	return -1
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