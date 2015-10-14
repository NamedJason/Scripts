#Configure and enable NTP on all ESXi hosts in an environment
#Usage: Hosts-NTP.ps1 -h <host name, wildcards accepted> -n <NTP Servers to add, comma seperated list for multiple servers>
#Author: Jason Coleman - virtuallyjason.blogspot.com

param(
	[alias("h")]
	[string]$hostIn = $(read-host -Prompt "Enter the target Host, wildcards accepted"),
	[alias("n")]
	[string]$NTPServersIn = "98.143.24.53, 129.6.15.28"
)

$AllHosts = Get-VMHost $hostIn
[string[]]$NTPServers = $NTPServersIn.split(",").trim()

foreach ($ThisHost in $AllHosts){
	#Gets current list of NTP servers from the host, then removes them all.
	$AllNTP = get-vmhostntpserver -VMHost $ThisHost
	foreach ($ThisNTP in $AllNTP)
	{
		echo "Removing $ThisNTP from $ThisHost"
		remove-vmhostntpserver -VMHost $ThisHost -ntpserver $ThisNTP -Confirm:$false
	}
	#Adds each of the new NTP servers to the host
	foreach ($ThisNTP in $NTPServers){
		echo "Adding $ThisNTP to $ThisHost"
		add-vmhostntpserver -VMHost $ThisHost -ntpserver $ThisNTP -Confirm:$false
	}
	#Restarts the NTP Service and turns it on
	Get-VMHostService -VMHost $ThisHost | where{$_.Key -eq "ntpd"} | restart-vmhostservice -Confirm:$false
	Get-VMHostService -VMHost $ThisHost | where{$_.Key -eq "ntpd"} | set-vmhostservice -policy "on" -Confirm:$false
}