#Detects and reports on any VMs that aren't part of any groups, then adds them to the specified Group
#Must have the DRSRule module from PowerCLIGoodies (available at https://github.com/PowerCLIGoodies/DRSRule)
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
	[parameter(parameterSetName='remediate']
	[string]$VMName
)

$clusterObj = get-cluster $cluster
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
