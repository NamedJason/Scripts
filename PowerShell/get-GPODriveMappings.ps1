#Gets a list of all User Preference Drive Mappings that are defined in the named GPO(s)
#Requires -Module ActiveDirectory
#Requires -Version 4.0
#Usage: get-GPODriveMappings.ps1 -GPOName <Name of GPO>
#Usage: $DriveMappings = get-GPODriveMappings.ps1 -GPOName (get-gpo -all).DisplayName
param
(
	$GPOName
)
$i = 0
$outReport = @()
foreach ($thisGPO in $GPOName){
	write-progress -activity "Getting GPO Settings" -status "Querying $thisGPO" -percentComplete ($i/$GPOName.count*100);$i++
	[XML]$GPO = Get-GPOReport -name $thisGPO -ReportType xml
	foreach ($thisDrive in $GPO.DocumentElement.user.ExtensionData.Extension.DriveMapSettings.Drive){
		$outObj = "" | select Drive,UNC,GroupFilter,UserFilter,GPOName
		$outObj.GPOName = $thisGPO
		$outObj.Drive = $thisDrive.name
		$outObj.UNC = $thisDrive.Properties.Path
		$GroupFilter = ""
		foreach ($thisFilter in $thisDrive.filters.FilterGroup){
			If ($thisFilter.not -eq 1){$groupFilter = $groupFilter + "!"}
			$GroupFilter = $GroupFilter + $thisFilter.Bool + " " + $thisFilter.Name + ";"
		}
		$outObj.GroupFilter = $GroupFilter
		$userFilter = ""
		foreach ($thisFilter in $thisDrive.filters.FilterUser){
			If ($thisFilter.not -eq 1){$userFilter = $userFilter + "!"}
			$userFilter = $userFilter + $thisFilter.Bool + " " + $thisFilter.Name + ";"
		}
		$outObj.userFilter = $userFilter
		$outReport += $outObj
	}
}
$outReport
