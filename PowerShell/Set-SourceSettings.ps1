param
(
	$directory = $(read-host "Enter local output directory"),
	[switch]$roles,
	[switch]$permissions,
	[switch]$folders,
	[switch]$vms
)

function make-ParentFolder
{
	Param
	(
		$inFolderArray
	)
	$parentFolder = get-folder VM
	foreach ($thisSubFolder in $inFolderArray)
	{
		if (!($parentFolder | get-folder $thisSubFolder -noRecursion -erroraction silentlycontinue))
		{
			$ParentFolder = $parentFolder | new-folder $thisSubFolder
		}
		else
		{
			$ParentFolder = $ParentFolder | get-folder $thisSubFolder -noRecursion
		}
	}
	$ParentFolder
}

$directory = $directory.trim("\") #" fix the gistit syntax highlighting

#Rebuild Folder Structure
if ($folders)
{
	$folderArray = import-clixml $directory\folders.xml
	foreach ($thisFolder in $folderArray)
	{
		make-ParentFolder $thisFolder.path
	}
}

#Rebuild Roles
if ($roles)
{
	$allRoles = import-clixml $directory\roles.xml
	foreach ($thisRole in $allRoles)
	{
		if (!(get-virole $thisRole.name -erroraction silentlycontinue))
		{
			new-virole -name $thisRole.name -privilege (get-viprivilege -id $thisRole.PrivilegeList)
		}
	}
}

#Rebuild Permissions
#Change this so that it uses make-ParentFolder, which means that it needs to store the informaiton better in the get script.
if ($permissions)
{
	$allPermissions = import-clixml $directory\permissions.xml
	foreach ($thisPermission in $allPermissions)
	{
		if ($thisFolder = get-folder $thisPermission.entity.name)
		{
			$thisFolder | new-vipermission -role $thisPermission.role -principal $thisPermission.principal -propagate $thisPermission.propagate
		}
	}
}

#Replace VMs
if ($VMs)
{
	$allVMs = import-clixml $directory\VMs.xml
	$allVApps = $NULL
	if (test-path $directory\vApps.xml){$allVApps = import-clixml $directory\vApps.xml}
	foreach ($thisVM in $allVMs)
	{
		if ($foundVM = get-vm $thisVM.name)
		{
			$ParentFolder = make-ParentFolder $thisVM.folderPath
			$foundVM | move-vm -folder $ParentFolder	
		}
	}
	foreach ($thisVApp in $allVApps)
	{
		echo "===$($thisVApp.name)==="
		$thisvApp.VMs
	}
	#Convert Template VMs back to Templates
}

if (!($VMs -or $folders -or $permissions -or $roles))
{
	echo "Please use one or more of the -VMs, -Folders, -Permissions, or -Roles switches to do something"
}
