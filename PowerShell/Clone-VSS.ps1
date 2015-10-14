#Copies a one host's standard vSwitch to another host
#Author: Jason Coleman (virtuallyjason.blogspot.com)
#Usage: Clone-VSS.ps1 -s [the name of the ESX host to copy the vSwitch from] -v [the name of the vSwitch to copy] -d [the name of the ESX host to copy the vSwitch to]
param
(
	[alias("s")]
	[string]$sourceHostString = $(read-host -Prompt "Enter the source Host"),
	[alias("v")]
	[string]$sourceVSwitchString = $(read-host -Prompt "Enter the Source Standard Virtual Switch"),
	[alias("d")]
	[string]$destinationHostString = $(read-host -Prompt "Enter the Destination Host")
)

#Get the destination host
$thisHost = get-vmhost $destinationHostString

#Get the source vSwitch and do error checking
$sVSwitch = get-vmhost $sourceHostString | get-virtualswitch -name $sourceVSwitchString -errorAction silentlycontinue
if (!($sVSwitch))
{
	write-host "$sourceVSwitchString was not found on $sourceHostString" -foreground "red"
	exit 1
}
if ($sVSwitch.count -ne 1)
{
	write-host "'$sourceVswitchString' returned multiple vSwitches; please use a more specific string." -foreground "red"
	$sVSwitch
	exit 4
}
if ($thisHost | get-virtualSwitch -name $sourceVSwitchString -errorAction silentlycontinue)
{	
	if ((($thisHost | get-virtualSwitch -name $sourceVSwitchString).uid) -like "*DistributedSwitch*")
	{
		write-host "$sourceVSwitchString is a Distributed vSwitch, exiting." -foreground "red"
		exit 3
	}
	$continue = read-host "vSwitch $sourceVSwitchString already exists on $destinationHostString; continue? [yes|no]"
	if (!($continue -like "y*"))
	{
		exit 2
	}
}
else
{
	#If the VSS doesn't already exist, create it
	$thisHost | new-virtualSwitch -name $sVSwitch.name > $null
}

#Make new Port Groups on the VSS
$destSwitch = $thisHost | get-virtualSwitch -name $sVSwitch.name
foreach ($thisPG in ($sVSwitch | get-virtualportgroup))
{
	#Skip this Port Group if it already exists on the destination vSwitch
	if ($destSwitch | get-virtualportgroup -name "$($thisPG.Name)" -errorAction silentlycontinue)
	{
		echo "$($thisPG.Name) already exists, skipping."
	}
	else
	{
		echo "Creating Port Group: $($thisPG.Name)."
		new-virtualportgroup -virtualswitch $destSwitch -name "$($thisPG.Name)" > $null
		#Assign a VLAN tag if there is one on the source Port Group
		if ($thisPG.vlanid -ne 0)
		{
			get-virtualportgroup -virtualswitch $destSwitch -name "$($thisPG.Name)" | Set-VirtualPortGroup -vlanid $thisPG.vlanid > $null
		}		
	}
}