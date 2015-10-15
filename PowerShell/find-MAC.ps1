param(
	[Parameter(Mandatory=$true)]
	[string]$MacAddress
)
echo ""
echo "Searching for VMs with a MAC address of $MacAddress..."
if ($foundVMs = get-view -viewtype virtualmachine | ? {$_.config.hardware.device.macaddress -like $MacAddress})
{
	$allVMs = get-vm $foundVMs.name
	$allVMs | get-networkadapter | ? {$_.MacAddress -like $MacAddress} | select @{Name="Object";Expression={$_.Parent}},@{Name="Adapter";Expression={$_.Name}},NetworkName
}
else
{
	write-host "No VMs found with a MAC Address of $MacAddress." -foregroundcolor "yellow"
}
echo ""
echo "Searching for VMKernel interfacse with a MAC address of $MacAddress..."
if ($foundHosts = get-view -viewtype hostsystem | ? {$_.config.network.vnic.spec.mac -like $MacAddress})
{
	$allHosts = get-vmhost $foundHosts.name
	$allHosts | get-vmhostnetworkadapter | ? {$_.Mac -like $MacAddress} | Select @{Name="Object";Expression={$_.VMHost}},@{Name="Adapter";Expression={$_.Name}}
}
else
{
	write-host "No VMK Interfaces found with a MAC Address of $MacAddress." -foregroundcolor "yellow"
}
