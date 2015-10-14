#Migrates 1 VM from a vSphere 4 environment into a vSphere 5 environment, performing most of the necessary upgrades for you.
#$VMString should be the name of the VM that you wish to migrate; wildcards are acceptable but it can only resolve to a single VM.
#$DestDSString is the name of the datastores that the script will choose from; it will select the datastore with the most free space from all datastores that match this naming pattern.
#$DestHostString should be the name of an ESX 5 host in the new environment with access to the desired storage
#$dataCenterString should be the name of the virtual datacenter in which the VM will reside
#$DSFreeSpace is an integer representing the % free space desired on the datastore after the VM is moved onto it; aborts if there is not enough space
param
(
	$VMString = (Read-Host("VM Name")),
	$DestDSString = (Read-Host("Destination Datastore")),
	$DestHostString = (Read-Host("Destination Host")),
	$dataCenterString = (Read-Host("Datacenter")),
	$DSFreeSpace = 20
)

$thisVM = Get-VM $VMString
if ($thisVM.Count -gt 1)
{
	echo "Too many VMs found that match string $VMString!"
	exit
}
if ((get-vm -name $VMString).ExtensionData.GuestHeartbeatStatus -eq "gray")
{
	echo "VM Tools not running, aborting script."
	exit
}
$destDS = (Get-Datacenter -name $dataCenterString | get-datastore -name $DestDSString | sort "freespacegb" -Descending)[0]
if ((($destDS.FreeSpaceGB - $thisVM.usedspaceGB) / $destDS.CapacityGB * 100) -lt $DSFreeSpace)
{
	echo "Destination Datastore $($destDS.name) will have less than $DSFreeSpace% free space.  Aborting migration."
	exit
}
$destHost = get-vmhost $DestHostString
echo "$thisVM current datastore: $($thisVM.DatastoreIDList)"
echo "$thisVM current network: $($thisVM.NetworkAdapters.NetworkName)"
echo "Shutting down $($thisVM.Name) for cold migration."
$thisVM | Shutdown-VMGuest -Confirm:$false
do
{
	echo "Waiting for shutdown to complete..."
	Start-Sleep -Seconds 15
} while ((get-vm -name $VMString).powerstate -eq "PoweredOn")
echo "Moving $thisVM to $destHost on $destDS"
Move-VM -VM $thisVM -Destination $destHost -datastore $destDS -DiskStorageFormat Thin | out-Null
$thisVM | New-Snapshot -Name "Pre-Upgrade" | out-Null
echo "Starting up $($thisVM.Name) for VMTools update."
$thisVM | Start-VM | out-Null
do
{
	echo "Waiting for startup to complete..."
	Start-Sleep -Seconds 15
} while ((get-vm -name $VMString).ExtensionData.GuestHeartbeatStatus -eq "gray")
Start-Sleep -Seconds 15
echo "Updating VMTools..."
$thisVM | Update-Tools | out-Null
Start-Sleep -Seconds 60
do
{
	echo "Waiting for startup to complete..."
	Start-Sleep -Seconds 15
} while ((get-vm -name $VMString).ExtensionData.GuestHeartbeatStatus -eq "gray")
echo "Shutting down $($thisVM.Name) for VM Hardware Version Update."
$thisVM | Shutdown-VMGuest -Confirm:$false
do
{
	echo "Waiting for shutdown to complete..."
	Start-Sleep -Seconds 15
} while ((get-vm -name $VMString).powerstate -eq "PoweredOn")
echo "Updating VM Hardware"
Set-VM -VM $thisVM -Version v9 -Confirm:$false

echo "-----"
echo "$($thisVM.Name)" 
echo ""
echo "VMTools version: $($thisVM.ExtensionData.Config.tools.ToolsVersion)"
echo "VM Hardware version: $((get-vm -name $VMString).version)"
echo "VM is on $($thisVM.DatastoreIdList.count) datastores."
echo "-----"