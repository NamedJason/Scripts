#Sets the boot delay to 5000 ms for each VM in the specified Resource Pool
#Based on Keith Luken's vmbootdelay.ps1 script
#Modification by Jason Coleman, 11/10/2014
param
(
    [int]$bootDelay = 5000,
    [string]$ResourcePool = "Customer-Resource-Pool",
    [string]$VM = "*"
)

#Gets all specified VMs from the appropriate resource pool
$vms = Get-ResourcePool -name $ResourcePool | Get-VM $VM

#Creates the VM config spec object with a 5000 ms boot delay
$vmbo = New-Object VMware.Vim.VirtualMachineBootOptions
$vmbo.BootDelay = $bootDelay
$vmcs = New-Object VMware.Vim.VirtualMachineConfigSpec
$vmcs.BootOptions = $vmbo

#Sets the boot delay for all VMs that do not currently have it, prompting the user for confirmation for each VM.
foreach ($thisVM in $vms)
{
    if ($thisvm.ExtensionData.config.BootOptions.BootDelay -ne $bootDelay)
	{
		[string]$response = Read-Host "Reconfigure $thisVM to have a $bootDelay ms boot delay (Y|N)?"
        switch -wildcard ($response)
        {
            "y*" {$thisVM.ExtensionData.ReconfigVM($vmcs)}
            "n*" {echo "skipping $thisVM"}
            default {echo "unexpected input, skipping $thisVM"}
        }
	}
}