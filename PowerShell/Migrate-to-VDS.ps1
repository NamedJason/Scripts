#Moves all VMs from Distributed Port Groups to Standard Port Groups as defined by an input translation table.  Designed to use the output translation table from Make-VSS.ps1
#Author: Jason Coleman (virtuallyjason.blogspot.com)
#Usage: Move-to-VSS.ps1 -h [the target ESXi host]
param
(
	[alias("h")]
	[string]$hostIn = $(read-host -Prompt "Enter the target Host"),
	[validateScript({test-path $_ -pathType leaf})]
	[alias("i")]
	[string]$inputFile = "C:\Temp\PGTranslations.xml"
)

#Build the Hashtable
$pgHash = @{}
$allPGs = import-clixml $inputFile
foreach ($thisPG in $allPGs)
{
	$pgHash.add($thisPG.VSSPG,$thisPG.dVSPG)
}

#Sets all VMs on the Host to the new VSS Port groups based on the Hashtable
$thisHost = get-vmhost $hostIn
foreach ($thisVM in ($thisHost | get-VM ))
{
	foreach ($thisNIC in ($thisVM | Get-NetworkAdapter))
	{
		if ($pgHash[$thisNIC.NetworkName])
		{
			if ($portGroup = $thisHost | get-virtualportgroup -name $pgHash[$thisNIC.NetworkName])
			{
				$thisNIC | set-networkadapter -confirm:$false -portgroup $portGroup
			}
			else
			{
				write-host "$($pgHash[$thisNIC.NetworkName]) does not exist."
			}
		}
		else
		{
			echo "$($thisVM.name) $($thisNIC.Name) uses $($thisNIC.NetworkName), which not have a match in the Hash Table."
		}
	}
}