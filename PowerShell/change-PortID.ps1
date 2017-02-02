param
(
	$pgSuffix = "-temp",
	$vmList = "E:\temp\VMs.csv",
	$vdSwitch = "*intranet*"
)
$affectedVMs = get-vm (import-CSV $vmList).name | ? {$_.powerstate -eq "PoweredOn"}
$affectedPortGroups = (get-view $affectedVMs.extensiondata.network).name
$affectedPortGroups = $affectedPortGroups | select -unique | sort

#Make Port Groups
$thisVDS = get-vdswitch $vdSwitch
$PGTranslations = @()
foreach ($thisPG in $affectedPortGroups){
	$pgTranslation = "" | select orig,temp
	$thisPortGroup = $thisVDS | get-vdportgroup $thisPG
	$pgTranslation.orig = $thisPortGroup
	write-host "Making $thisPG$pgSuffix, using $($thisPortGroup.PortBinding) and teaming $(($thisPortGroup | get-VDUplinkTeamingPolicy).LoadBalancingPolicy) and VLAN $($thisPortGroup.VLANconfiguration.VLANID)"
	if ($pgTranslation.temp = $thisVDS | get-vdportgroup "$thisPG$pgSuffix" -erroraction silentlycontinue)
	{
		write-host "$thisPG$pgSuffix already exists, skipping..."
	}
	else
	{
		$dvsPortGroup = $thisVDS | new-vdportgroup -name "$thisPG$pgSuffix"
		$dvsPortGroup | Set-VDPortgroup -PortBinding $thisPortGroup.PortBinding | select Name,PortBinding  | fl
		$dvsPortGroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -LoadBalancingPolicy ($thisPortGroup | get-VDUplinkTeamingPolicy).LoadBalancingPolicy | select @{expression={$_.VDPortgroup}; label='Name'},LoadBalancingPolicy | fl
		if ($thisPortGroup.VLANconfiguration.VLANID) {$dvsPortGroup | Set-VDVlanConfiguration -vlanid $thisPortGroup.VLANconfiguration.VLANID | select Name,@{ expression={$_.vlanconfiguration.vlanid}; label='VLAN'} | fl}
		$pgTranslation.temp = $dvsPortGroup
	}
	$PGTranslations += $pgTranslation
}

write-host "Port Group Creation Complete:"
$PGTranslations
pause

#Move the VM NICs
foreach ($thisVM in $affectedVMs){
	foreach ($thisNIC in ($thisVM | get-networkadapter)){
		if ($translationRow = $PGTranslations | ? {$_.orig.name -eq $thisNIC.networkname}){
			$origPortGroup = $translationRow.orig
			$tempPortGroup = $translationRow.temp
			write-host "Migrating $($thisVM.name) from $($origPortGroup.name) to $($tempPortGroup.name)..."
			pause
			$thisNIC | set-networkadapter -confirm:$false -portgroup $tempPortGroup
			start-sleep 2
			write-host "Migrating $($thisVM.name) from $($tempPortGroup.name) to $($origPortGroup.name)..."
			$thisNIC | set-networkadapter -confirm:$false -portgroup $origPortGroup
		}
		else {
			write-error "$($thisNIC.networkname) does not exist in the translation table.  This should not have happened; was the VM manipulated after the script started?"
		}

	}
}
