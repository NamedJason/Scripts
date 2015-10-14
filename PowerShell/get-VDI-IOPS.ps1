#Grab metrics from logged in VDI desktops to help expand an existing environment.
#Uses a standard deviation calculation function from Richard Siddaway at https://richardspowershellblog.wordpress.com/2011/07/12/standard-deviation/

param (
	$standardDevs = 1
)

#Richard Siddaway's Standard Deviation function
function get-standarddeviation {
	[CmdletBinding()]
	param (
		[double[]]$numbers
	)

	$avg = $numbers | Measure-Object -Average | select Count, Average
	$popdev = 0

	foreach ($number in $numbers){
		$popdev +=  [math]::pow(($number - $avg.Average), 2)
	}

	$sd = [math]::sqrt($popdev / ($avg.Count-1))
	$sd
}

$outObjs = @()
$activeVMs = get-vm (((Get-RemoteSession | ? {$_.state -eq "CONNECTED"}).DNSName) | % {$_.split(".")[0]})
$activeVMs | foreach {
	#create the basic VM object and populate the easy parameters
	$thisVM = "" | select Name, Memory, CPUs, WriteIOPS, ReadIOPS
	$thisVM.Name = $_.Name
	$thisVM.Memory = $_.memoryGB
	$thisVM.CPUs = $_.numCPU

	#Collect Write IOPS Number for the VM based on X standard deviations
	# $writeMetrics = ($_ | Get-Stat -Realtime -stat "disk.numberWriteAveraged.average").value
	# $writeAverage = ($writeMetrics | measure-object -average).average
	# $writeDev = 0
	# $writeMetrics | foreach {$writeDev += [math]::pow(($_ - $writeAverage),2)}
	# $writeSD = [math]::sqrt($writeDev / ($writeMetrics.count-1))
	# $thisVM.WriteIOPS = $writeAverage + $standardDevs * $writeSD
	$writeMetrics = ($_ | Get-Stat -Realtime -stat "disk.numberWriteAveraged.average").value
	$thisVM.WriteIOPS = get-standarddeviation($writeMetrics)

	#Collect Read IOPS Number for the VM based on X standard deviations
	# $readMetrics = ($_ | Get-Stat -Realtime -stat "disk.numberReadAveraged.average").value
	# $readAverage = ($readMetrics | measure-object -average).average
	# $readDev = 0
	# $readMetrics | foreach {$readDev += [math]::pow(($_ - $readAverage),2)}
	# $readSD = [math]::sqrt($readDev / ($readMetrics.count-1))
	# $thisVM.ReadIOPS = $readAverage + $standardDevs * $readSD
	$readMetrics = ($_ | Get-Stat -Realtime -stat "disk.numberReadAveraged.average").value
	$thisVM.ReadIOPS = get-standarddeviation($readMetrics)
	
	# $thisVM.WriteIOPS =  (($_ | Get-Stat -Realtime -stat "disk.numberWriteAveraged.average").value | measure-object -Maximum).maximum
	# $thisVM.ReadIOPS =  (($_ | Get-Stat -Realtime -stat "disk.numberReadAveraged.average").value | measure-object -Maximum).maximum

	$outObjs += $thisVM
}
$outObjs | export-csv VM-Perf.csv
