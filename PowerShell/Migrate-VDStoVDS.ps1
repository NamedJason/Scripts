#Moves all VMs from VDS Port Groups to VDS Port Groups as defined by an input translation table.  This assumes that the port groups will be on one of two switches; either External or Internal, and is set to check each of them.
#Translation table must be a CSV with two columns specifying equivelencies: RealPG and TempPG
#Author: Jason Coleman (virtuallyjason.blogspot.com)
#Usage: Migrate-VDStoVDS.ps1 -h [the target ESXi host] -t <path to translation file> (-toReal | -toTemp)
param
(
	[alias("h")]
	[string]$hostIn = $(read-host -Prompt "Enter the target Host"),
	[validateScript({test-path $_ -pathType leaf})]
	[alias("t")]
	[string]$translationFile = "E:\Temp\PGTranslations.csv",
	[string]$extName = "*Extranet-Temp",
	[string]$intName = "*Intranet-Temp",
	[switch]$toReal,
	[switch]$toTemp
)
$newIntSwitch = get-vdswitch -name $intName
$newExtSwitch = get-vdswitch -name $extName

#Build the Hashtable.  It looks for the first item and moves VMs onto the second item.  To change from temp to prod, just switch the order of the objects in the hash table
if ($toReal -and $toTemp){write-error "May only migrate -toReal or -toTemp, not both";exit 10}
$pgHash = @{}
$allPGs = import-csv $translationFile
if(!(($allPGs | gm).name -contains "tempPG" -and ($allPGs | gm).name -contains "realPG")){write-error "translationFile missing tempPG or realPG column(s)";exit 12}
foreach ($thisPG in $allPGs)
{
	if ($toTemp){$pgHash.add($thisPG.RealPG, $thisPG.TempPG)}
	elseif ($toReal){$pgHash.add($thisPG.TempPG, $thisPG.RealPG)}
	else{write-error "Neither -toTemp nor -toReal are specified";exit 11}
}

#Sets all VMs on the Host to the new VDS Port groups based on the Hashtable
$thisHost = get-vmhost $hostIn
foreach ($thisVM in ($thisHost | get-VM ))
{
	foreach ($thisNIC in ($thisVM | Get-NetworkAdapter))
	{
		if ($pgHash[$thisNIC.NetworkName])
		{
			if ($portGroup = $newIntSwitch | get-vdportgroup -name $pgHash[$thisNIC.NetworkName] -erroraction SilentlyContinue)
			{
				$thisNIC | set-networkadapter -confirm:$false -portgroup $portGroup
			}
			elseif ($portGroup = $newExtSwitch | get-vdportgroup -name $pgHash[$thisNIC.NetworkName] -erroraction SilentlyContinue)
			{
				$thisNIC | set-networkadapter -confirm:$false -portgroup $portGroup
			}
			else
			{
				echo "$($thisVM.name) $($thisNIC.Name) uses $($thisNIC.NetworkName), which not have a match in the destination DVS."
			}
		}
		else
		{
			echo "$($thisVM.name) $($thisNIC.Name) uses $($thisNIC.NetworkName), which not have a match in the Hash Table."
		}
	}
}