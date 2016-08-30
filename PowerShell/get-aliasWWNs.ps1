#Generates a list of all Brocade Aliases and all ESXi HBAs, then compares them against eachother to find out of use aliases
#As input takes $BrocadeSwitches (CSV with IP,Creds columns), $vCenterServers (CSV with vCenter column), $creds (get-credential powerShell Object with AD credentials for vCenter)
#The $BrocadeSwitches csv file's "Creds" column must point to the XML output of a PowerShell credential object that has a valid username/password for each switch (get-credential | export-clixml credentials.xml)
param
(
	$BrocadeSwitches,
	$vCenterServers,
	$creds,
	$directory = "."
)
function get-BrocadeAliases{
	#Gets all Aliases from the specified Fiber Switch
	Param
	(
		$user,
		$switch,
		$password
	)
	$a = plink $user@$switch -pw $password "alishow"
	$end = $a.count - 1

	#Get a list of all line numbers that contain an alias: entry
	$aliasLines = @()
	0..$end | % {
		if ($a[$_] -match '^ alias'){
			$aliasLines += $_
		}
	}

	#Create PowerShell Objects out of the Aliases
	$colOut = @()
	foreach ($thisLine in $aliasLines) {
		$objOut = "" | select Alias,WWN,SwitchIP
		$objOut.SwitchIP = $switch
		if (($a[$thisLine].trim() -split "`t").count -gt 2){
			#Line has Alias and WWN on same line
			$objOut.Alias = (($a[$thisLine]).trim() -split "`t")[1]
			$objOut.WWN = (($a[$thisLine]).trim() -split "`t")[2]
		}
		else{
			#Line has Alias and WWN on adjascent lines
			$objOut.Alias = (($a[$thisLine]).trim() -split "`t")[1]
			$objOut.WWN = $a[$thisLine+1].trim()
		}
		#remove the colons to make it easier to compare to the PowerCLI output
		$objOut.WWN = ($objOut.WWN).replace(":","")
		$colOut += $objOut
	}
	$colOut
}
function Get-ESXiWWNs{
	param
	(
		$vCenter = $(read-host "vCenter"),
		$creds
	)
	connect-viserver -server $vcenter -user $creds.username -password $creds.getnetworkcredential().password > $NULL
	#Quit if the connect failed, so as to not lock out the user account in case of typo'ed password
	if (!($?)) {exit 11}
	$allHBAs = get-vmhost | get-vmhosthba | select vmhost,device,@{N="WWN";E={"{0:X}"-f$_.PortWorldWideName}} | ? {$_.WWN}
	disconnect-viserver -server $vcenter -confirm:$false
	$allHBAs
}
#Prepare a list of all Aliases on all known switches
$proceed = "yes"
if (test-path $directory\allAliases.csv -erroraction silentlycontinue)
{
	$proceed = read-host "Overwrite the stored AllAliases.csv file [y|n]"
}
if ($proceed -like "y*")
{
	$allSwitches = import-csv $brocadeSwitches
	$allAliases = @()
	foreach ($thisSwitch in $allSwitches)
	{
		write-host "Working on $($thisSwitch.IP)"
		if ($creds = import-clixml $thisSwitch.CredsFile)
		{
			$allAliases += get-BrocadeAliases -user $creds.username -password $creds.getnetworkcredential().password -switch $thisSwitch.IP
		}
		else
		{
			write-error "Unable to read Credentials File $($thisSwitch.CredsFile)"
		}
	}
	$allAliases | export-csv $directory\allAliases.csv
}
else
{
	$allAliases = import-csv $directory\allAliases.csv
}

#Prepare a list of all ESXi WWNs
$proceed = "yes"
if (test-path $directory\allESXiWWNs.csv -erroraction silentlycontinue)
{
	$proceed = read-host "Overwrite the stored allESXiWWNs.csv file [y|n]"
}
if ($proceed -like "y*")
{
	$allESXiWWNs = @()
	if ($allvCenters = import-csv $vCenterServers)
	{
		foreach ($thisvCenter in $allvCenters)
		{
			write-host "Working on $($thisvCenter.vCenter)"
			$allESXiWWNs += Get-ESXiWWNs -vCenter $thisVcenter.vCenter -creds $creds
		}
		write-host "Writing AllESXiWWNs output file..."
		# $allESXiWWNs | export-clixml allESXiWWNs.xml
		$allESXiWWNs | export-csv $directory\allESXiWWNs.csv
	}
	else
	{
		write-error "Unable to import vCenter List: $vCenterServers"
	}
	
}
else
{
	$allESXiWWNs = import-csv $directory\allESXiWWNs.csv
}

write-host "Comparing the results..."
$compareResults = compare-object $allESXiWWNs.wwn $allAliases.wwn
$oddESXi = @()
$oddAliases = @()
foreach ($thisResult in ($compareResults | ? {$_.sideindicator -eq "<="}))
{
	$oddESXi += $allESXiWWNs | ? {$_.WWN -eq $thisResult.inputObject}
}
foreach ($thisResult in ($compareResults | ? {$_.sideindicator -eq "=>"}))
{
	$oddAliases += $allAliases | ? {$_.WWN -eq $thisResult.inputObject}
}

$oddESXi | export-csv $directory\OddESXi.csv
$oddAliases | export-csv $directory\OddAliases.csv