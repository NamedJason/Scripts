#Sets all LUNs from a given vendor to use a given path selection policy on a given host(s).  Defaults to setting all 3PAR storage to use RoundRobin.  Passing the "-r:$TRUE" option sets it to Report Only mode where it reports all LUNs from the vendor, highlighting those that do not conform to the selected policy
#Author: Jason Coleman
#Usage: .\Assign-RR.ps1 [-h <Hostname, wildcards accepted>] [-v <storage vendor string>] [-p <Path Selection Policy>] [-r:$True]

param(
[alias("h")]
[string]$thisHost = $(read-host -Prompt "Enter the target Host"),
[alias("v")]
[string]$thisVendor = "3PARdata",
[alias("p")]
[string]$thisPolicy = "RoundRobin",
[alias("r")]
[boolean]$justReport = $FALSE
)

$allLUNs = get-vmhost -name $thisHost | Get-ScsiLun -LunType disk
foreach ($thisLUN in $allLUNs | where {$_.Vendor -eq $thisVendor})
{
	If ($justReport)
	{
		"Host: $($thisLUN.VMHost) LUN: $($thisLUN.RuntimeName)"
	}
	If ($thisLUN.MultipathPolicy -ne $thisPolicy)
	{
		If ($justReport)
		{
			"***Host: $($thisLUN.VMHost) LUN: $($thisLUN.RuntimeName) PSP: $($thisLUN.MultipathPolicy)"
		}
		else
		{
			$thisLUN | set-scsilun -MultipathPolicy $thisPolicy
		}
	}
}