function get-rdmData {
	#expects an array of VM Objects for the $VMs parameter, returns a table of any RDMs found on those VMs.
	param(
		$vms
	)
	$output = @()
	$i = 0
	foreach ($vm in $vms){
		write-progress -activity "Checking VMs for Shared SCSI Buses" -status $vm.name -percentComplete ($i++/$vms.count*100)
		$controllers = $vm | get-scsicontroller | ? {$_.BusSharingMode -ne "NoSharing"}
		foreach ($controller in $controllers){
			$vmdks = $vm | get-harddisk | ? {$_.extensiondata.controllerkey -eq $controller.extensiondata.key}
			foreach ($vmdk in $vmdks){
				#try to rewrite this to use get-harddisk objects instead of get-view stuff
				$outObj = "" | select vmname,vmdk,controllerID,busSharingMode,controllerType,deviceID,deviceName,ScsiCanonicalName
				$outObj.vmname = $vm.name
				$outObj.vmdk = $vmdk.filename
				$outObj.busSharingMode = $controller.busSharingMode
				$outObj.controllerID = $controller.extensiondata.busnumber
				$outObj.controllerType = $controller.Type
				$outObj.deviceID = $vmdk.extensiondata.unitnumber
				$outObj.deviceName = $vmdk.deviceName
				$outObj.ScsiCanonicalName = $vmdk.ScsiCanonicalName
				$output += $outObj
			}
		}
	}
	$output
}

function copy-RDMConfig {
	#copies $sourceVM's shared hard disk configuration onto $destVM
	param(
		$sourceVM,
		$destVM
	)
	$sourceControllers = $sourceVM | Get-ScsiController | ? {$_.bussharingmode -ne "nosharing"}
	$allSourceHDs = $sourceVM | get-harddisk
	foreach ($sourceController in $sourceControllers){
		$sourceHDs = $allSourceHDs | ? {$_.extensiondata.controllerkey -eq $sourceController.key}
		#Define the new SCSI Controller in the $Spec object
		$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
		$spec.DeviceChange += New-Object VMware.Vim.VirtualDeviceConfigSpec 
		$spec.deviceChange[0].device += $sourceController.ExtensionData 
		$spec.deviceChange[0].device.Key = -101
		$spec.deviceChange[0].operation = "add"
		#Process each RDM on the Source VM and create $Spec entries for them
		$i = 0
		foreach ($sourceHD in $sourceHDs){
			$i++
			$spec.DeviceChange += New-Object VMware.Vim.VirtualDeviceConfigSpec
			$spec.deviceChange[$i].device += $sourceHD.ExtensionData
			$spec.deviceChange[$i].device.Key = -(101 + $i)
			$spec.deviceChange[$i].device.ControllerKey = -101
			$spec.deviceChange[$i].operation = "add"
		}
		#Reconfig the Destination VM using the spec that was built
		$destVM.ExtensionData.ReconfigVM_Task($spec) | wait-task
	}
}
