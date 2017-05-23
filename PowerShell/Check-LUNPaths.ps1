#Checks a group of hosts for potential zoning or san presentation inconsistencies
$outReport = @()
foreach ($thisCluster in (get-cluster))
{
	$scsiLunCount = 0
	foreach ($thisHost in ($thisCluster | get-vmhost))
	{
		write-host "Working on $($thisHost.name)..."
		foreach ($thisHBA in ($thisHost | get-vmhosthba | ? {$_.type -eq "FibreChannel"}))
		{	
			$outHBA = "" | select Cluster,Host,ExpectedLUNs,ActualLUNs,VMHBA
			$outHBA.VMHBA = $thisHBA.device
			$outHBA.Cluster = $thisCluster.name
			$outHBA.Host = $thisHost.name
			$outHBA.ActualLUNs = ($thisHBA | get-scsiLUN).count
			if ($scsiLunCount -ne 0)
			{
				if ($scsiLUNCount -ne $outHBA.ActualLUNs)
				{
					#Bad condition
					write-error "$thisHost $($thisHBA.name) does not have $scsiLUNCount LUNs."
				}
			}
			else
			{
				$scsiLUNCount = $outHBA.ActualLUNs
			}
			$outHBA.ExpectedLUNs = $scsiLunCount
			$outReport += $outHBA
		}
	}
}
$outReport
