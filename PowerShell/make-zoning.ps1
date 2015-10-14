#Generate Brocade CLI commands to create aliases and 1:1 zones.  After these commands are run, use the GUI to modify and enable the config.
#Change the $targets array to contain the target aliases on this switch
#Change the $initiator variable to reflect the HBA that is plugged into this switch
#Change the $vmHosts line to restrict this to specific hosts in the environment
param
(
	$targets = @("HappyFunSPA1","HappyFunSPB1"),
	$initiator = "vmhba1",
	$vmHosts = "*",
	$outFile = ""
)
$allVMHosts = get-vmhost $vmHosts

$allCommands = @()
$outCommands = @()

#Gets a list of selected HBAs on selected Hosts, formatting the WWN as Hex instead of Decimal
$allHBAs = $allVMHosts | get-vmhosthba -device $initiator | select vmhost,device,@{N="WWN";E={"{0:X}"-f$_.PortWorldWideName}}
#Gets the Shortname for the ESXi hosts and replace dashes with underscores
$allHBAs | foreach {$_.VMHost = $_.VMHost.tostring().split('.')[0]}
$allHBAs | foreach {$_.VMHost = $_.VMHost.replace("-","_")}
#Adds colons between every two characters of the WWN
$allHBAs | foreach {$_.WWN = ($_.WWN -split '(..)' | ? {$_}) -join ':'}

#Generates the Brocade CLI commands to create the Alias and then the Zones
foreach ($thisHBA in $allHBAs)
{
	$thisVMHost = $thisHBA.VMHost
	$thisDevice = $thisHBA.device
	$thisWWN = $thisHBA.WWN
	
	#Use this command to verify that the WWN is advertised on that switch
	$allCommands += "nsshow | grep $thisWWN"
	#Create the Alias
	$thisAlias = "$thisVMHost`_$thisDevice"
	$allCommands += "aliCreate ""$thisAlias"", ""$thisWWN"""
	#loop to create Zones
	foreach ($thisTarget in $targets)
	{
		$allCommands += "zoneCreate ""$thisAlias`_$thisTarget"", ""$thisAlias;$thisTarget"""
	}
}
#reorganize the commands for output in a more human friendly order
$outCommands += $allCommands | where {$_ -like "nsshow*"}
$outCommands += $allCommands | where {$_ -like "aliCreate*"} | sort
$outCommands += $allCommands | where {$_ -like "zoneCreate*"} | sort
$outCommands += "cfgSave"

$outCommands
if ($outFile) {$outCommands > $outFile}