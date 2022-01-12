#Change VM Network Configuration
#change-VMNetwork.ps1 -thisVM <VM Object> -portGroup <Destination Port Group Name> -IPAddress <new IP> -subnetCIDR <new subnet as CIDR> -gateway <new Gateway> -DNSServers <array of DNS server IP addresses>
param (
	[VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl]$thisVM,
	[string]$portGroup,
	[string]$IPAddress,
	[string]$subnetCIDR,
	[string]$gateway,
	[string]$adapterName = "*",
	[string[]]$DNSServers
)

$stepResults = "" | select IPResults,PortGroupResults

#Move the VM to the specified Port Group
$stepResults.PortGroupResults = $thisVM | get-networkAdapter | set-networkAdapter -portGroup (get-vdPortGroup $portGroup) -confirm:$false

#Build a script for the VM to execute via vmtools
$script = @"
`$adapter = @()
`$adapter += get-netAdapter | ? {`$_.name -like "$adapterName"}
if (`$adapter.count -eq 1){
	new-netIPAddress -interfaceIndex `$adapter.ifIndex -ipAddress $IPAddress -prefixLength $subnetCIDR -defaultGateway $gateway
} else {
	return "ERROR: " + `$adapter.count + " Network Adapters found that match the name: " + "$adapterName"
}
set-DNSClientServerAddress -InterfaceIndex `$adapter.ifIndex -serverAddresses @("$($DNSServers -join '","')")
"@

$stepResults.IPResults = ($thisVM | Invoke-VMScript $script).scriptOutput
$stepResults
