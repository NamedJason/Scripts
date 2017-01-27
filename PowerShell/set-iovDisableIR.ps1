# Set iovDisableIR to false and REBOOTS ESXi hosts to resolve a PSOD issue; targets hosts that are already in maintenance mode
# Usage: set-iovDisableIR.ps1 [-ReportOnly] [-Setting [$True|$False]]
# Example 1: Report on the iovDisableIR Setting for a set of hosts in maintenance mode:
# set-iovDisableIR.ps1 -reportOnly
# Example 2: Disable the iovDisableIR setting for a set of hosts in maintenance mode:
# set-iovDisableIR.ps1
param
(
	[switch]$ReportOnly,
	[boolean]$Setting = $FALSE
)
#Get all Hosts that are in maintenance mode
$allHosts = get-vmhost -state Maintenance | sort name
foreach ($thisHost in $allHosts){
	$esxcli = get-esxcli -VMHost $thisHost -v2
	if ($reportOnly){
		#Generate a report showing hostname, configured setting and current runtime setting
		$esxcli.system.settings.kernel.list.invoke() | ? {$_.name -like 'iovDisableIR'} | select @{N="Host";E={$thisHost.name}},configured,runtime
	}
	else{
		#Check if the host needs the change
		if (($esxcli.system.settings.kernel.list.invoke() | ? {$_.name -like 'iovDisableIR'}).runtime -ne $setting){
			write-host "Working on $($thisHost.name)..."
			$arguments = $esxcli.system.settings.kernel.set.CreateArgs()
			$arguments.setting = "iovDisableIR"
			$arguments.value = $setting
			$esxcli.system.settings.kernel.set.Invoke($arguments)
			$thisHost | restart-vmhost
		}
		else {write-host "Skipping $($thisHost.name) because iovDisableIR is already configured to $Setting"}
	}
}
