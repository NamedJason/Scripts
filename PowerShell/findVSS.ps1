#Finds all VMs (and Templates) in an environment that are still attached to Standard vSwitches
$allVMs = get-vm
$allVMs += get-template
foreach ($thisVM in $allVMs)
{
	#clears the error variable from the previous VM, then attempts to get a list of Distributed Port Groups that the VM uses and checks for null network names
	$errVar = ""
	#Ensure that the VM has a NIC before proceeding, ignore it if it doesn't
	if (($thisVM | get-networkadapter).count -lt 1)
	{
		#echo "$($thisVM.name) has no NIC"
	}
	else
	{
		#If the VM has an adapter that isn't Distributed, check the type of error.  If it's the expected one, report the VM otherwise report the exception.
		get-vdportgroup ($thisVM | get-networkadapter).networkName -errorAction silentlycontinue -errorVariable errVar > $null
		if ($errVar -ne "")
		{
			if ($errVar.Exception.message.contains("not found"))
			{
				echo "$($thisVM.name) is not entirely on the dVS"
			}
			else
			{
				echo "Unexpected error while examining $($thisVM.name):"
				$errVar.Exception.message
			}
		}
	}
}