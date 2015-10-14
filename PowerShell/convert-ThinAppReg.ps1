#Takes a thinapp registry differential output (from 'vregtool Registry.rw.tvr PrintKeys - ShowValues -ShowData -ExpandMacros') and generates a series of "reg add" commands to create the HKLM and HKCU registry entries contained within.
param
(
	$inFile = "C:\temp\reg-everything.txt"
)
$regAdds = @()
$allReg = Get-Content $inFile
foreach ($thisLine in $allReg)
{
	#reformats the line to better match "reg add" syntax
	$thisLine = $thisLine.trim()
	$thisLine = $thisLine -replace "HKEY_LOCAL_MACHINE", "HKLM"
	$thisLine = $thisLine -replace "HKEY_CURRENT_USER", "HKCU"
	$thisLine = $thisLine -replace "^ *writecopy", ""
	$thisLine = $thisLine -replace "^ *deleted", ""
	$thisLine = $thisLine -replace "^ *sb_only", ""
	$thisLine = $thisLine -replace "^ *full", ""
	if ($thisLine -match "^ *REG_SZ")
	{
		$thisLine = $thisLine -replace "#00\) *$", ")"
	}
	$thisLine = $thisLine.trim()
	
	if (($thisLine.startswith("HKLM")) -or ($thisLine.startswith("HKCU")))
	{
		#Just specifying the key path
		$thisKey = $thisLine
	}
	elseif (($thisLine.startswith("REG")))
	{
		#Create the reg add command for the new value, correcting for "" value and data fields
		$thisCommand = ($thisLine.trim()).split(" ")
		$regType = $thisCommand[0]
		$valueStartPos = $thisLine.IndexOf("[") + 1
		$valueStrLength = $thisLine.IndexOf("]") - $valueStartPos
		$regValue = "`"$($thisLine.Substring($valueStartPos,$valueStrLength))`""
		$regValue = $regValue -replace "`"`"`"`"", "`"`""
		$dataStartPos = $thisLine.IndexOf("(") + 1
		$dataStrLength = $thisLine.LastIndexOf(")") - $dataStartPos
		$regData = "`"$($thisLine.Substring($dataStartPos,$dataStrLength))`""
		$regData = $regData -replace "`"`"`"`"", "`"`""
		$regAdds += "reg add `"$thisKey`" /v $regValue /t $regType /d $regData /f"
	}
}
$regAdds