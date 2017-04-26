#check-pnicVLANs.ps1
#Reports DVS PNICs with observed invalid VLAN traffic.  Uses the Port Groups on the VDS to determine what VLANs are valid, flags if it finds VLANs that are not represented by Port Groups.
#usage: check-pnicVLANs.ps1 -vdswitch <switch name>
#usage: $a = @(); get-vdswitch | % {$a += check-pnicVLANs.ps1 -vdswitch $_}
#Examines the PNIC hints (using techniques from poshcode.org/1653) to find if any PNICs on a VDS observe VLANs that are outside of the specified acceptable range.
param
(
	$vdswitch
)
write-host "Getting ESXi hosts and Distributed Switch $vdswitch..."
$vdswitch = get-vdswitch $vdswitch
$allHosts = $vdswitch | get-vmhost
$portGroups = $vdswitch | get-vdportgroup
$out = @()
#Get the valid list of VLANs
$validVLANs = $portGroups.vlanconfiguration.vlanid | sort | get-unique

#Check the host pnics
foreach ($vmhost in $vdswitch.ExtensionData.Config.Host){
	$outObj = "" | select vmHost,WrongVLANs,vDSwitch,validVLANs
	$vmhostObj = $allHosts | ? {$_.id -like "*$($vmhost.config.host.value)"}
	write-host "Working on $($vmhostObj.name)..."
	$outObj.vmHost = $vmhostObj.name
	$outObj.vDSwitch = $vdswitch.name
	$outObj.validVLANs = $validVLANs -join(", ")
	$hostView = $vmhostObj | Get-View -Property ConfigManager
	$ns = Get-View $hostView.ConfigManager.NetworkSystem
	foreach ($vmnic in $vmhost.config.backing.pnicspec.pnicdevice){
		$vlans = $ns.QueryNetworkHint($vmnic).subnet.vlanid | sort
		if ($vlans){
			if ($bad = (compare-object $validVLANs $vlans | ? {$_.sideIndicator -eq "=>"}).inputObject){
				write-host "$($outObj.vmHost) $vmnic has out of range VLANs" -foregroundcolor red
				$outObj.WrongVLANs += $bad
			}
		}
		else
		{
			write-host "$($outObj.vmHost) $vmnic has no observed VLANs" -foregroundcolor yellow
		}
		$outObj | add-member -membertype NoteProperty -name "$vmnic`_Observed" -value ($vlans -join(", "))
	}
	$outObj.WrongVLANs = $outObj.WrongVLANs -join(", ")
	$out += $outObj
}
$out
