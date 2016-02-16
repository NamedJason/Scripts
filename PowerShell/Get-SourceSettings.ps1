#Get Data from Source vCenter
param
(
	$directory = $(read-host "Enter local output directory"),
	[switch]$getTemplates
)
#Takes a VI Folder object and returns an array of strings that represents that folder's absolute path in the inventory
function get-folderpath
{
	param
	(
		$thisFolder
	)
	#Creates an array of folders back to the root folder
	if ($thisFolder.id -like "Folder*")
	{
		$folderArray = @()
		$folderArray += $thisFolder
		while ($folderArray[-1].parent.parent.id -notLike "Datacenter*")
		{
			$folderArray += $folderArray[-1].parent
		}
		# $folderArray = $folderArray[0..$folderArray.count-2]
		[array]::Reverse($folderArray)
		#convert the array of folders to an array of strings with just the folder names
		$folderStrArray = @()
		$folderArray | %{$folderStrArray += $_.name}
		$folderStrArray
	}
	else
	{
		write-error "Unexpected input provided; does not appear to be a Folder."
	}
}

$directory = $directory.trim("\") #" This comment is to fix the gistit syntax highlighting.
new-item $directory -type directory -erroraction silentlycontinue

#Get Roles
get-virole | ? {$_.issystem -eq $false} | export-clixml $directory\roles.xml

#Get Permissions
get-vipermission | export-clixml $directory\permissions.xml

#Get VM Folder Structure
$outFolders = @()
foreach ($thisFolder in (get-folder | ? {$_.type.tostring() -eq "VM" -and $_.parent.id -notLike "Datacenter*"}))
{
	$myFolder = "" | select path
	$myFolder.path = get-folderpath $thisFolder
	$outFolders += $myFolder
}
$outFolders | export-clixml $directory\folders.xml

#Convert Templates to VMs (so that they can transition vCenters)
get-template | select name | export-clixml $directory\Templates.xml
if ($getTemplates){get-template | set-template -ToVM -confirm:$false}

#Get VM Locations
$outVMs = @()
$allVApps = get-vapp
$vAppVMs = $allVApps | get-vm
if ($vAppVMs)
{
	$allVMs = Get-VM | ? {!($vAppVMs.contains($_))}
	#Deal with vApps... maybe try this guy's technique to capture settings and make a best effort at recreating the vApp?
	# http://www.lukaslundell.com/2013/06/modifying-vapp-properties-with-powershell-and-powercli/
	$outVApps = @()
	foreach ($thisVApp in $allVApps)
	{
		write-error "Discovered VAPP: $($thisVApp.name) - vAPPs must be recreated manually."
		$myVApp = "" | select name,VMs
		$myVApp.name = $thisVApp.name
		$myVApp.VMs = ($thisVApp | get-vm).name
		$outVApps += $myVApp
	}
	$outVApps | export-clixml $directory\vApps.xml
}
else
{
	$allVMs = get-VM
}
foreach ($thisVM in $allVMs)
{
	$myVM = "" | select name,folderPath
	$myVM.name = $thisVM.name
	if ($thisVM.folder.name -eq "VM")
	{
		$myVM.folderPath = $NULL
	}
	else
	{
		$myVM.folderPath = get-folderpath $thisVM.folder
	}
	$outVMs += $myVM
}
$outVMs | export-clixml $directory\VMs.xml
