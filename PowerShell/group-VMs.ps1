<#
.SYNOPSIS
This script detects VMs that belong to no DRS Rule VM Group and places them into the specified group.  It requires the DRSRule module.

.Example 
./group-vm.ps1 -report -cluster <host cluster name>
Discovers all VMs in the specified cluster that are not in any DRS Rule VM Group

.Example
./group-vm.ps1 -placeVMs -cluster <host cluster name> -groupName <DRS Group name>
Discovers all VMs in the specified cluster that are not members of any DRS Rule VM Group and places them into the specified DRS Rule Group

.Example
./group-vm.ps1 -placeVMs -cluster <host cluster name> -groupName <DRS Group name> -VMName <VM Name>
Discovers all VMs in the specified cluster that are not members of any DRS Rule VM Group and match the specified RegEx, then places them into the specified DRS Rule Group

.Description
Written by Jason Coleman (virtuallyjason.blogspot.com).  Requires the DRSRule module from https://github.com/PowerCLIGoodies/DRSRule
#>

#Requires -modules DRSRule
param
(
	[parameter(parameterSetName='remediate',Mandatory=$true)]
	[switch]$placeVMs,
	[parameter(parameterSetName='report',Mandatory=$true)]
	[switch]$report,
	[parameter(Mandatory=$true)]
	[string]$Cluster,
	[parameter(parameterSetName='remediate',Mandatory=$true)]
	[string]$GroupName,
	[parameter(parameterSetName='remediate')]
	[string]$VMName
)

if (!($clusterObj = get-cluster $cluster)){exit 10}
$groupedVMs = @()

#Get a list of all VMs that are not part of any DRS VM Group
write-host "Detecting DRS Cluster VM Groups..."
$clusterObj | get-drsvmgroup | foreach {$groupedVMs += $_.vm}
$groupedVMs = $groupedVMs | select -unique
$allVMs = ($clusterObj | get-vm).name
$ungroupedVMs = (compare-object $allVMs $GroupedVMs | ? {$_.SideIndicator -eq "<="}).InputObject

if ($report)
{
	write-host "$('='*40)"
	write-host "Machines that are not part of any group:"
	write-host "$('='*40)"
	$ungroupedVMs
}
	
#Adds ungrouped VMs to the specfied group
if ($placeVMs)
{
	$ungroupedVMs = $ungroupedVMs | ? {$_ -match $VMName}
	if ($destinationGroup = $clusterObj | get-DrsVMGroup -name $groupName)
	{
		foreach ($thisVM in $ungroupedVMs)
		{
			write-host "Adding $thisVM to the $($destinationGroup.name) group."
			$destinationGroup | Set-DrsVMGroup -vm (get-vm $thisVM) -Append > $NULL
		}
	}
	else
	{
		write-error "Default group $groupName was not found on the $cluster cluster."
	}
}
