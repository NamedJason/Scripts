#Run on destination vCenter to recreate VM folder structure and permissions
param
(
	[alias("d")]
	$directory = $(read-host "Enter input directory"),
	[alias("dc")]
	$datacenter = $(read-host "Enter datacenter name")
)
$directory = $directory.trim("\")
#Read in the folder structure from the Get-SourceSettings.ps1 script and create those VM Folders
foreach ($thisFolder in (import-clixml $directory\folders.xml | where {!($_.name -eq "vm")})) {(get-datacenter $datacenter) | get-folder $thisFolder.Parent | new-folder $thisFolder.Name -confirm:$false}
#Read in Roles from Get-sourceSettings.ps1 script and create those Roles
foreach ($thisRole in (import-clixml $directory\roles.xml)){if (!(get-virole $thisRole.name -erroraction silentlycontinue)){new-virole -name $thisRole.name -Privilege (get-viprivilege -id $thisRole.PrivilegeList)}}
#Read in Permissions from Get-sourceSettings.ps1 script and assign those permissions
foreach ($thisPerm in (import-clixml $directory\permissions.xml)) {get-folder $thisPerm.entity.name | new-vipermission -role $thisPerm.role -Principal $thisPerm.principal -propagate $thisPerm.Propagate}
#Read in the VM Folder locations and move the VMs to their Folders; only execute this line after all VMs have been moved into the new inventory
#$allVMs = import-clixml C:\Temp\vm-locations.xml | where ($_.name -like "goldview*")
#foreach ($thisVM in $allVMs) {get-vm $thisVM.name | move-vm -destination (get-folder $thisVM.folder)}