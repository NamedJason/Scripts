# Export source Folders/Roles/Permissions/VM Locations
param
(
	[alias("d")]
	$directory = read-host "Enter output directory",
	[alias("dc")]
	$datacenter = read-host "Enter datacenter name"
)
$directory = $directory.trim("\")
new-item $directory -type directory -erroraction silentlycontinue
get-virole | where {$_.issystem -eq $false} | export-clixml $directory\roles.xml
Get-VIPermission | export-clixml $directory\permissions.xml
$dc = get-datacenter $datacenter
$dc | get-folder | where {$_.type -eq "VM"} | select name,parent | export-clixml $directory\folders.xml
$dc | get-vm | select name,folder | export-clixml $directory\vm-locations.xml