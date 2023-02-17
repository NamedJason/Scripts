#Returns the path data for all ESXi hosts connected to the given datastore(s)
#assumes that you are already connected to vCenter
#usage: .\report-datastorePaths.ps1 -datastoreName <name of datastore to examine; multiple datastores may be specified with wildcards> -alertThreshold <if the number of active paths is less than this number, alert the user>
param (
	[string]$datastoreName = "*lun*",
	[int]$alertThreshold = 4
)
try{
	$Datastores = get-datastore -name $datastoreName -erroraction stop | sort -unique name
	$allHosts = $Datastores | get-vmhost -erroraction stop | sort -unique name
} catch {
	$_
	continue
}

$report = foreach ($thisHost in $allHosts){
	try {
		$esxcli = $thisHost | get-esxcli -v2
	} catch {
		$_
		continue
	}
	
	foreach ($Datastore in $Datastores){
		$objReport = "" | select vmhost,datastore,paths
		$objReport.vmhost = $thisHost.name
		$objReport.datastore = $Datastore.name
		$naaID = $Datastore.extensiondata.info.vmfs.extent.diskname
		$arguments = $esxcli.storage.core.path.list.createArgs()
		$arguments.device = $naaID
		$paths = ($esxcli.storage.core.path.list.invoke($arguments)).state
		$objReport.paths = $paths -join ", "
		if (($paths | ? {$_ -eq "active"}).count -lt $alertThreshold){
			write-host "$($thisHost.name) has fewer than $alertThreshold active paths to $($Datastore.name)" -foregroundcolor red
			write-host "$($objReport.paths)"
		}
		$objReport
	}
}
$report
