#Discover which VMs were either Shut Down or Powered Off in the last day
$allVMs = get-vm
$targetVMs = @()
foreach ($thisVM in $allVMs)
{
	$events = $thisVM | get-vievent -start ((get-date).adddays(-1).tostring().split(" ")[0])
	if ($events.FullFormattedMessage -contains "Task: Initiate guest OS shutdown" -or $events.FullFormattedMessage -contains "Task: Power Off virtual machine")
	{
		$thisVM.name
		$targetVMs += $thisVM
	}
}
read-host "Press Enter to power on the discovered VMs..."

#Power on the VMs...
foreach ($thisVM in $targetVMs)
{
	if ($thisVM.powerstate -eq "poweredoff"){$thisVM | start-VM}
	Start-Sleep 15 #avoid a boot storm; adjust this delay based on your environment.
}
