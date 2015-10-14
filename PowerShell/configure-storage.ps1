#Sets all LUNs from a given vendor to use a given path selection policy on a given host(s).  Defaults to setting all 3PAR storage to use RoundRobin.  Passing the "-r" option sets it to Report Only mode where it reports all LUNs from the vendor, highlighting those that do not conform to the selected policy
#Author: Jason Coleman and Dennis Bray
#Usage: .\configure-storage.ps1 [-h <Hostname, wildcards accepted>] [-v <storage vendor string>] [-p <Path Selection Policy>] [-r]

param(
	[alias("h")]
	[string]$hostIn = $(read-host -Prompt "Enter the target Host"),
	[alias("v")]
	[string]$thisVendor = "3PARData",
	[alias("p")]
	[string]$thisPolicy,
	[int]$queueFullSample,
	[int]$queueFullThreshold,
	[alias("r")]
	[switch]$justReport
)

if (($thisPolicy -eq $null) -or ($queueFullSample -eq $null) -or ($queueFullThreshold -eq $null) -or ($thisVendor -eq $null))
{
	switch ($thisVendor)
	{
		"3PARData"
		{
			$thisPolicy = "RoundRobin"
			$queueFullSample = 32
			$queueFullThreshold = 4
		}
		Default
		{
			Echo "Warning: No preconfigured values defined for storage vendor '$thisVendor', please supply required information."
			if ($thisVendor -eq $null)
			{
				$thisVendor = $(read-host -Prompt "Enter the desired storage vendor")
			}
			if ($thisPolicy -eq $null)
			{
				$thisPolicy = $(read-host -Prompt "Enter the desired path selection policy")
			}
			if ($queueFullSample -eq $null)
			{
				$queueFullSample = $(read-host -Prompt "Enter the desired Queue Full Sample size")
			}
			if ($queueFullThreshold -eq $null)
			{
				$queueFullThreshold = $(read-host -Prompt "Enter the desired Queue Full Threshold size")
			}
		}
	}
}

$allHosts = get-vmhost $hostIn
foreach ($thisHost in $allHosts)
{
	Connect-VIServer $thisHost.name | out-null
	$esxcli = Get-EsxCli -VMHost $thisHost
	$allLUNs = get-vmhost -name $thisHost.name | Get-ScsiLun -LunType disk
	foreach ($thisLUN in $allLUNs | where {$_.Vendor -eq $thisVendor})
	{
		echo "Host: $($thisLUN.VMHost) LUN: $($thisLun.CanonicalName)"
		If ($thisLUN.MultipathPolicy -ne $thisPolicy)
		{
			echo ""
			if (!($justReport))
			{
				echo "Original PSP: $($thisLUN.MultipathPolicy), Attempting to set as: $thisPolicy"
				$thisLUN | set-scsilun -MultipathPolicy $thisPolicy | out-null
			}
			$thisLunPolicy = (get-vmhost -name $thisHost.name | get-ScsiLun -LunType disk -CanonicalName $thisLun.CanonicalName).MultipathPolicy
			echo "Policy currently set as: $thisLunPolicy"
		}
		if (!($justReport))
		{
			echo ""
			echo "Setting Queue Full Sample Size and Threshold..."
			$esxcli.storage.core.device.set($thisLUN.CanonicalName,$null,$null,$queueFullSample,$queueFullThreshold,$null)
		}
		echo "Queue Full Sample Size: $(($esxcli.storage.core.device.list($thisLUN.CanonicalName)).QueueFullSampleSize)"
		echo "Queue Full Threshold: $(($esxcli.storage.core.device.list($thisLUN.CanonicalName)).QueueFullThreshold)"

	}
	disconnect-VIServer $thisHost.name -Confirm:$false
}