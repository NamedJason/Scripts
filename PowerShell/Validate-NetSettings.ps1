#Test network settings for common errors.  Ensures IP Address, Gateway, and DNS Servers are all valid IP addresses and that the Subnet Mask is a valid mask.  Returns the Subnet Mask in CIDR notation if everything is successful.
#Ensures tha the Gateway address is on the same subnet as the provided IP Address.
#Usage: Validate-NetSettings -ipAddress <IP> -gateway <Gateway> -subnetMask <subnet mask in dotted notation> -DNSServers <Array of DNS Server IPs>
param (
	[Parameter(Mandatory=$true)]
	[string]$ipaddress,
	
	[Parameter(Mandatory=$true)]
	[string]$gateway,
	
	[Parameter(Mandatory=$true)]
	[string]$subnetMask,
	
	[Parameter(Mandatory=$true)]
	[string[]]$DNSServers
)

try {
	$ipSubnet = ([ipaddress](([ipaddress]$ipaddress).address -band ([ipaddress]$subnetMask).address)).ipaddresstostring
	$gatewaySubnet = ([ipaddress](([ipaddress]$Gateway).address -band ([ipaddress]$subnetMask).address)).ipaddresstostring
	if ($ipSubnet -ne $gatewaySubnet){
		throw "IP Address $($ipAddress) with Subnet Mask $($subnetMask) cannot access Gateway $($gateway)"
	}
	$subnetMaskBinary = ($SubnetMask -split "\." | % {[convert]::tostring($_,2).padleft(8,"0")}) -join ""
	if ($subnetMaskBinary -notmatch "(^1+)0+$" -or $subnetMaskBinary.length -ne 32){throw "Invalid subnet mask: $(subnetmask)"}
	$subnetCIDR = $matches[1].length
	$DNSServers | % {
		[ipaddress]$_ | out-null
	}
	return $subnetCIDR
}
catch {
	return $_.Exception.Message
}
