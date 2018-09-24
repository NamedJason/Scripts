#Collects and summarizes the Real Time average network usage for all powered-on VMs every interval over a duration
#Usage: .\summarize-VMNetUsage.ps1 | export-csv C:\temp\NetUsageSummary.csv
#intervalMinues <integer>: Capture the Real Time stats every <integer> minutes - use 60 or more since it captures 60 minutes worth of data each time
#durationHours <integer>: Run this capture over this duration in hours.
param(
	$intervalMinutes = 60,
	$durationHours = 24
)
function get-VMNetUseSummary {
	$allVMs = get-vm | ? {$_.powerstate -eq "poweredon"} | sort name
	$networkUsage = @()
	$i = 1
	#Gets the highest average network usage for all VMs in the environment
	foreach ($vm in $allVMs){
		write-progress -id 1 -activity "Getting VM Network Usage" -status "Checking $($vm.name)..." -percentComplete ($i++ / $allVMs.count * 100)
		$networkUsage += (get-stat -Entity $vm -stat "net.usage.average" -realtime).value | sort -Descending | select -first 1
	}
	#Creates a summary with Sum, Average, Maximum and Date for the network usage of the whole environment
	$summary = $networkUsage | Measure-Object -sum -average -maximum -minimum
	$summary | add-member -name "Date" -force -MemberType NoteProperty -value (get-date)
	$summary
}
$endTime = (get-date).addHours($durationHours)
$results = @()
#Gets the VM network usage stats at most once every interval for the specified duration
do {
	$startTime = get-date
	$results += get-VMNetUseSummary
	write-progress -id 1 -activity "Getting VM Network Usage" -status "Waiting until $($startTime.addminutes($intervalMinutes)) to begin next polling cycle"
	do {
		start-sleep 60
	} until ((get-date) -gt $startTime.addminutes($intervalMinutes))
} until ((get-date) -gt $endTime)
$results
