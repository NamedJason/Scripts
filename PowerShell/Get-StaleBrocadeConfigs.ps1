#Get Stale Brocade Configuration Entries
#Signs retrieves the Brocade switch configuration and checks each Alias' WWN against nsshow results to see if it is active or not.  Reports all zones with inactive aliases.
#Needs plink to be installed and accessible at the command line
#Example: get-StaleBrocadeConfigs.ps1 -user admin -password <password> -switch <switchIP>
param
(
	$user = "admin",
	$switch,
	$password
)
#Check for plink...
try{
	plink > $NULL
}
catch{
	throw "PLINK was not found on this system.  Please ensure that it can be executed directly from the command line and try again."
}

#Get the current switch configuration
write-progress -Activity "Collecting switch configuration"
if (!($plinkAlishow = plink $user@$switch -pw $password 'alishow')){
	throw "No Brocade configuration discovered with $user@$switch"
}

#Get the switch configuration and convert it to an array of objects
$switchConfig = @()
$switchConfig += "Type Name Data Stale Command Notes"
for ($i=0;$i -lt $plinkAlishow.count;$i++){
	#Only record lines that define an Alias or a Zone
	if ($plinkAlishow[$i].trim() -match "^(alias|zone)"){
		$configLine = ($plinkAlishow[$i] -replace "\s+"," ").trim()
		#Check the next line to see if it's a continuation of the current definition and append it, as needed
		$nextLine = $plinkAlishow[$i+1] -replace "\s+",""
		while ($nextLine -and !($nextLine -match "^(alias|zone|Effective)")){
			#Create a ; delimited list for secondary data objects, but make sure that there's a space if this is the first data object
			if ($configLine.split(" ").count -lt 3){
				$delimiter = " "
			}
			else{
				$delimiter = ";"
			}
			$configLine = $configLine + $delimiter + $nextLine
			#Loop through the config to discover all secondary data objects that belong to this primary object
			$i++
			$nextLine = $plinkAlishow[$i+1] -replace "\s+",""
		}
		$switchConfig += $configLine.trim()
	}
	#Stop after processing the Defined Configuration
	if ($plinkAlishow[$i].trim() -eq "Effective configuration:"){
		$i = $plinkAlishow.count
	}
}
$switchConfig = $switchConfig | ConvertFrom-Csv -Delimiter " "

#Get all of the WWNs in the config
$allWWNs = ($switchConfig.data | ? {$_ -match "^\d{2}:"}) -split ";" | sort | get-unique

#Remove duplicate Aliases and Zones
$switchConfig = $switchConfig | sort type,name
$switchConfig = $switchConfig | get-unique -asstring

#Get the currently signed in WWNs
write-progress -Activity "Collecting switch configuration" -completed
write-progress -Activity "Looking for stale entries"
if (!($plinkWWNs = plink $user@$switch -pw $password 'nsshow')){
	throw "No active WWNs discovered with $user$$switch"
}

#find which WWNs are Active/Stale
$staleWWNs = @()
$activeWWNs = @()
foreach ($thisWWN in $allWWNs){
	if (!($plinkWWNs | ? {$_ -match $thisWWN})){
		$staleWWNs += $thisWWN
	}
	else{
		$activeWWNs += $thisWWN
	}
}

#find the Aliases with WWNs that are not logged in
foreach ($thisAlias in $switchConfig){
	if ($thisAlias.type -eq "Alias:"){
		if (!($plinkWWNs | ? {$_ -match $thisAlias.Data})){
			$thisAlias.Stale = $TRUE
		}
	}
}

#Find all config lines that involve stale aliases or WWNs
$staleAliases = ($switchConfig | ? {$_.stale -eq $TRUE}).Name
foreach ($thisLine in $switchConfig){
	if (!($thisLine.stale)){
		foreach ($staleAlias in $staleAliases){
			if ($thisLine.data -match $staleAlias -or $thisLine.name -match $staleAlias){
				$thisLine.stale = $TRUE
			}
		}
	}
	if (!($thisLine.stale)){
		foreach ($staleWWN in $staleWWNs){
			if ($thisLine.data -match $staleWWN){
				$thisLine.stale = $TRUE
			}
		}
	}
	if (!($thisLine.stale)){$thisLine.stale = $FALSE}
}

#Try to detect false positives (zones with a stale alias but 2 or more active aliases or WWNs
$activeDevices = ($switchConfig | ? {$_.type -eq "Alias:" -and !($_.stale)}).name
$activeDevices += $activeWWNs
foreach ($thisLine in $switchConfig){
	$theseActive = @()
	if (($thisLine.stale) -and $thisLine.type -eq "zone:"){
		foreach ($thisMember in ($thisLine.data -split ";")){
			if ($activeDevices -contains $thisMember){$theseActive += $thisMember}
		}
		if ($theseActive.count -ge 2){
			$thisLine.stale = "Suspect"
			$thisLine.notes = "Active Aliases: " + ($theseActive -join " ") + "."
		}
	}
}

#Create Remediation Commands
foreach ($thisObj in $switchConfig){
	if ($thisObj.stale){
		if ($thisObj.Type -eq "Alias:"){
			$thisObj.Command = "aliDelete ""$($thisObj.name)"""
		}
		elseif($thisObj.Type -eq "Zone:"){
			$thisObj.Command = "zoneDelete ""$($thisObj.name)"""
		}
		else {
			write-error "Unknown object type for: " + ($thisObj | convertto-csv -delimiter " ")[-1]
		}
	}
}
write-progress -Activity "Looking for stale aliases" -completed
$switchConfig
