#Requires -modules vmware.powercli
#Requires -modules powervrni
# Creates VRNI Applications based on the VM folders within vCenter, populating each application with the VMs in each folder.
# -folder is a regex to match many VM folders within the inventory
#Make sure that you're connected to your vCenter and your vRNI before executing
#Connect-vRNIServer -server <vRNI Server> -username 'admin@local'
#Connect-viserver <vCenter Server>
param (
	$folder
)
$vcDrive = new-psdrive -location (get-folder VM) -name vcInventory -PSProvider VimInventory -root '\'
$allVMs = ls vcInventory:\ -recurse | ? {!$_.psiscontainer}
$rootPath = "" + $vcDrive.provider  + "::" + $vcDrive.Root + "\"

#Only work with VMs in the specified folder
$vmFolders = $allVMs | select name,@{n="folder";e={$_.psparentpath.replace($rootPath,'')}} | ? {$_.folder -match $folder}

#Add application and tier properties to each VM based on its folder path.  Clean up the path to use dash and underscore.
foreach ($vm in $vmFolders){
	$application = "vc_" + $vm.folder.replace("\","-").replace(" ","_")
	$vm | add-member -type noteproperty -name "application" -value $application -force
}

#Create the vRNI Applications and tiers and populate them with the VMs
$existingApplications = Get-vRNIApplication
$applications = $vmFolders.application | select -unique

$conflicts = $applications | ? {$existingApplications.name -contains $_}
if ($conflicts){
	foreach ($application in $conflicts){
		write-host -foregroundcolor "red" "$Application already exists, please remove and try again."
	}
	break
}

#All applications are new, so create them.
$results = @()
foreach ($application in $applications){
	#Add machines to the application
	$applicationVMs = $vmFolders | ? {$_.application -eq $application}
	$thisApplication = new-vrniapplication -name $application
	$tiers = $application
	foreach ($tier in $tiers){
		#register and populate the tier
		$actionObj = "" | select Application,Filter
		$vmfilters = "name = '" + (($applicationVMs | ? {$_.application -eq $application}).name -join "' or name = '") + "'"
		$actionObj.application = $application
		$actionObj.filter = $vmfilters
		$results += $actionObj
		$thisApplication | new-vrniApplicationTier -name $tier -vmfilters $vmfilters
	}
}
