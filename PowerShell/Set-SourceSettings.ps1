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
		if (!(get-folder $thisSubFolder -erroraction silentlycontinue))
		{
			$ParentFolder = $parentFolder | new-folder $thisSubFolder -noRecursion
		}
		else
		{
			$ParentFolder = get-folder $thisSubFolder -noRecursion
		}
	}
	$ParentFolder
}

$directory = $directory.trim("\")

#Rebuild Folder Structure
if ($folders)
{
	$folderArray = import-clixml $directory\folders.xml
	foreach ($thisFolder in $folderArray)
	{
		make-ParentFolder $thisFolder
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
			new-virole -name $thisRole.name -privilege (get-viprivege -id $thisRole.PrivilegeList)
		}
	}
}

#Rebuild Permissions
if ($permissions)
{
	$appPermissions = import-clixml $directory\permissions.xml
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
	$allVApps = import-clixml $directory\vApps.xml
	foreach ($thisVM in $allVMs)
	{
		$ParentFolder = make-ParentFolder $thisVM.folderPath
		get-vm $thisVM.name | move-vm -folder $ParentFolder
	}
	foreach ($thisVApp in $allVApps)
	{
		echo ===$thisVApp.name===
		$thisvApp.VMs
	}
}

if (!($VMs -and $folders -and $permissions -and $roles)
{
	echo "Please use one or more of the -VMs, -Folders, -Permissions, or -Roles switches to do something"
}
