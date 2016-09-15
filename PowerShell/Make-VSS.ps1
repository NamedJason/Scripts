#Copies all Port Groups from a Distributed vSwitch to a Standard vSwitch
#Author: Jason Coleman (virtuallyjason.blogspot.com)
#Usage: Make-VSS.ps1 -h [the target ESXi host to get the new standard switch, must have access to the DVS] -s [the name of the DVS to copy] -d [the name of the VSS to copy the Port Groups to]

param
(
	[alias("h")]
	[string]$thisHost = $(read-host -Prompt "Enter the target Host"),
	[alias("s")]
	[string]$source = $(read-host -Prompt "Enter the Source Distributed Virtual Switch name"),
	[alias("d")]
	[string]$destination = $(read-host -Prompt "Enter the Destination Virtual Switch name"),
	[alias("o")]
	[string]$outputFile = "E:\Temp\PGTranslations.xml"
)
#Create an empty array to store the port group translations
$pgTranslations = @()
#Get the destination vSwitch
if (!($destSwitch = Get-VirtualSwitch -host $thisHost -name $destination)){write-error "$destination vSwitch not found on $thisHost";exit 10}
#Get a list of all port groups on the source distributed vSwitch
if (!($allPGs = get-vdswitch -name $source | get-vdportgroup)){write-error "No port groups found for $source Distributed vSwitch";exit 11}
foreach ($thisPG in $allPGs)
{
	$thisObj = new-object -Type PSObject
	$thisObj | add-member -MemberType NoteProperty -Name "dVSPG" -Value $thisPG.Name
	$thisObj | add-member -MemberType NoteProperty -Name "VSSPG" -Value "$($thisPG.Name)-VSS"
	new-virtualportgroup -virtualswitch $destSwitch -name "$($thisPG.Name)-VSS"
	# Ensure that we don't try to tag an untagged VLAN
	if ($thisPG.vlanconfiguration.vlanid)
	{
		get-virtualportgroup -virtualswitch $destSwitch -name "$($thisPG.Name)-VSS" | Set-VirtualPortGroup -vlanid $thisPG.vlanconfiguration.vlanid
	}
	$pgTranslations += $thisObj
} 

$pgTranslations | export-clixml $outputFile
