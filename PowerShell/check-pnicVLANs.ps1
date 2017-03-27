#check-pnicVLANs.ps1
#Reports DVS PNICs with observed invalid VLAN traffic
#usage: check-pnicVLANs.ps1 -vdswitch <switch name> -minVLANID <number> -maxVLANID <number>
#Examines the PNIC hints (using techniques from poshcode.org/1653) to find if any PNICs on a VDS observe VLANs that are outside of the specified acceptable range.
param
(
	$vdswitch,
	[int]$minVLANID = 0,
	[int]$maxVLANID = 4096
)
write-host "Getting ESXi hosts and Distributed Switch..."
$allHosts = get-vmhost
$vdswitch = get-vdswitch $vdswitch
$out = @()
foreach ($vmhost in $vdswitch.ExtensionData.Config.Host){
	$outObj = "" | select vmHost,MinVLANID,MaxVLANID
	$vmhostObj = $allHosts | ? {$_.id -like "*$($vmhost.config.host.value)"}
	write-host "Working on $($vmhostObj.name)..."
	$outObj.vmHost = $vmhostObj.name
	$outObj.MinVLANID = $minVLANID
	$outObj.MaxVLANID = $maxVLANID
	$hostView = $vmhostObj | Get-View -Property ConfigManager
	$ns = Get-View $hostView.ConfigManager.NetworkSystem
	foreach ($vmnic in $vmhost.config.backing.pnicspec.pnicdevice){
		$vlans = $ns.QueryNetworkHint($vmnic).subnet.vlanid | sort
		if ($vlans){
			if ($vlans[0] -lt $minVLANID -or $vlans[-1] -gt $maxVLANID){
			write-host "$($outObj.vmHost) $vmnic has out of range VLANs" -foregroundcolor red
			}
		}
		else
		{
			write-host "$($outObj.vmHost) $vmnic has no observed VLANs" -foregroundcolor yellow
		}
		$outObj | add-member -membertype NoteProperty -name $vmnic -value ($vlans -join(", "))
	}
	$out += $outObj
}
$out
