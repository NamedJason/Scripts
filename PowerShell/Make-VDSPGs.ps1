#Create Distributed Port Groups from input file, skipping correctly configured existing port groups
#Config file: Name, VLAN, PortBinding, DVS
[cmdletbinding(SupportsShouldProcess=$True)]
Param
(
	[validateScript({test-path $_ -pathType leaf})]
	[alias("c")]
	[string]$configFile = "E:\Temp\DVS.csv",
	[alias("f")]
	[switch]$fixErrors,
	[alias("v")]
	[string]$vdswitch = ""
)

#If a distributed vSwitch is specified, verify that it exists.
if ($vdswitch)
{
	if (!(get-vdswitch -name $vdswitch -erroraction silentlycontinue))
	{
		write-host "Distributed vSwitch $vdswitch does not exist." -foreground "red"
		exit 20
	}
}

$allPortGroups = import-csv $configFile | where {($_.DVS -match $vdswitch) -or ($_.DVS -match "^$($vdswitch.split('-')[1])")}

#Verify that the input file contains all of the necessary columns.
@("Name","VLAN","PortBinding","DVS") | foreach {
	if (!($allPortGroups | gm -name $_))
	{
		write-host "$configFile does not contain a '$_' column." -foreground "red"
		exit 10
	}
}

#Read through each defined Port Group from the input file, creating/correcting them as needed.
foreach ($thisPortGroup in $allPortGroups)
{
	$thisSwitch = get-vdswitch "*$($thisPortGroup.DVS)" -erroraction silentlycontinue
	if (!($thisSwitch))
	{
		write-host "vSwitch $($thisPortGroup.DVS) was not found, skipping port group $($thisPortGroup.name)" -foreground "red"
	}
	else
	{
		#Distributed switch already exists, deal with the port group.
		if ($dvsPortGroup = $thisSwitch | get-vdportgroup -name $thisPortGroup.name -erroraction silentlycontinue)
		{
			#Portgroup already exists
			#Check and correct, as needed, Portbinding, Load Balancing and VLAN settings
			if (!($dvsPortGroup.PortBinding -eq $thisPortGroup.PortBinding) -and ($pscmdlet.ShouldProcess($thisPortGroup.name)))
			{
				write-host "$($thisPortGroup.name) already exists, but the PortBinding is set to $($dvsPortGroup.PortBinding)" -foreground "yellow"
				if ($fixErrors -and ((read-host "Correct this misconfiguration [y|n]") -like "y*"))
				{
					$dvsPortGroup | set-VDPortgroup -PortBinding $thisPortGroup.PortBinding | select Name,PortBinding  | fl
				}
			}
			
			if (!(($dvsPortGroup | get-VDUplinkTeamingPolicy).LoadBalancingPolicy -eq "LoadBalanceLoadBased") -and ($pscmdlet.ShouldProcess($thisPortGroup.name)))
			{
				write-host "$($thisPortGroup.name) already exists, but the Load Balancing Policy is not 'Route based on Physical NIC Load'" -foreground "yellow"
				if ($fixErrors -and ((read-host "Correct this misconfiguration [y|n]") -like "y*"))
				{
					$dvsPortGroup | get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -LoadBalancingPolicy LoadBalanceLoadBased | select @{expression={$_.VDPortgroup}; label='Name'},LoadBalancingPolicy | fl
				}
			}
			
			if (!($dvsPortGroup.vlanconfiguration.vlanid -eq $thisPortGroup.VLAN) -and ($pscmdlet.ShouldProcess($thisPortGroup.name)))
			{
				write-host "$($thisPortGroup.name) already exists, but the VLAN ID is set to $($dvsPortGroup.vlanconfiguration.vlanid)" -foreground "yellow"
				if ($fixErrors -and ((read-host "Correct this misconfiguration [y|n]") -like "y*"))
				{
					$dvsPortGroup | Set-VDVlanConfiguration -vlanid $thisPortGroup.VLAN | select Name,@{ expression={$_.vlanconfiguration.vlanid}; label='VLAN'} | fl
				}
			}
		}
		else
		{
			#Create the Portgroup
			#set the Portbinding, Load Balancing and VLAN settings
			if ($pscmdlet.ShouldProcess($thisPortGroup.name))
			{
				$dvsPortGroup = $thisSwitch | new-vdportgroup -name $thisPortGroup.name
				$dvsPortGroup | Set-VDPortgroup -PortBinding $thisPortGroup.PortBinding | select Name,PortBinding  | fl
				$dvsPortGroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -LoadBalancingPolicy LoadBalanceLoadBased | select @{expression={$_.VDPortgroup}; label='Name'},LoadBalancingPolicy | fl
				if ($thisPortGroup.VLAN -ne 0) {$dvsPortGroup | Set-VDVlanConfiguration -vlanid $thisPortGroup.VLAN | select Name,@{ expression={$_.vlanconfiguration.vlanid}; label='VLAN'} | fl}
			}
		}
	}
}
