#requires -modules powerNSX
#get-appliedNSXIPsets
#given a specific IP Address, returns the NSX IP Sets and Security Groups that contain it
#Does not support IP Sets that are defined as a range, like 192.168.1.23-192.168.1.34.  Only supports specific IP Addresses or subnets in CIDR notation
param (
	$IPAddr
)
function IPInRange {
	#from https://github.com/omniomi/PSMailTools/blob/v0.2.0/src/Private/spf/IPInRange.ps1
	#This function is available under the MIT license
    [cmdletbinding()]
    [outputtype([System.Boolean])]
    param(
        # IP Address to find.
        [parameter(Mandatory,
                   Position=0)]
        [validatescript({
            ([System.Net.IPAddress]$_).AddressFamily -eq 'InterNetwork'
        })]
        [string]
        $IPAddress,

        # Range in which to search using CIDR notation. (ippaddr/bits)
        [parameter(Mandatory,
                   Position=1)]
        [validatescript({
            $IP   = ($_ -split '/')[0]
            $Bits = ($_ -split '/')[1]

            (([System.Net.IPAddress]($IP)).AddressFamily -eq 'InterNetwork')

            if (-not($Bits)) {
                throw 'Missing CIDR notiation.'
            } elseif (-not(0..32 -contains [int]$Bits)) {
                throw 'Invalid CIDR notation. The valid bit range is 0 to 32.'
            }
        })]
        [alias('CIDR')]
        [string]
        $Range
    )

    # Split range into the address and the CIDR notation
    [String]$CIDRAddress = $Range.Split('/')[0]
    [int]$CIDRBits       = $Range.Split('/')[1]

    # Address from range and the search address are converted to Int32 and the full mask is calculated from the CIDR notation.
    [int]$BaseAddress    = [System.BitConverter]::ToInt32((([System.Net.IPAddress]::Parse($CIDRAddress)).GetAddressBytes()), 0)
    [int]$Address        = [System.BitConverter]::ToInt32(([System.Net.IPAddress]::Parse($IPAddress).GetAddressBytes()), 0)
    [int]$Mask           = [System.Net.IPAddress]::HostToNetworkOrder(-1 -shl ( 32 - $CIDRBits))

    # Determine whether the address is in the range.
    if (($BaseAddress -band $Mask) -eq ($Address -band $Mask)) {
        $true
    } else {
        $false
    }
}

$ipsets = get-nsxIPSet
$ipsets = foreach ($ipSet in $ipSets){
	foreach ($range in ($ipset.value -split ",")){
		$objIPRange = "" | select name,range
		$objIPRange.name = $ipset.name
		$objIPRange.range = $range
		$objIPRange
	}
}
$results = @()
$results += ($ipsets | ? {$_.range -match "\/"} | ? {IPInRange -ipAddress $ipAddr -range $_.range}).name
$results += ($ipsets | ? {$_.range -notmatch "\/" -and $_.range -notmatch "-"} | ? {$ipAddr -eq $_.range}).name
$results = $results | sort -unique
$groups = get-nsxsecuritygroup

foreach ($result in $results){
	$NSXgroups = ($groups | ? {$_.member.name -contains $result})
	if (!$NSXGroups){
		$objResult = "" | select NSXSecurityGroup,NSXIPSet,IPAddress
		$objResult.IPAddress = $IPAddr
		$objResult.NSXIPSet = $result
		$objResult.NSXSecurityGroup = ""
		$objResult
	}
	foreach ($group in $NSXGroups){
		$objResult = "" | select NSXSecurityGroup,NSXIPSet,IPAddress
		$objResult.IPAddress = $IPAddr
		$objResult.NSXIPSet = $result
		$objResult.NSXSecurityGroup = ($group.name | sort -unique) -join ", "
		$objResult
	}
}
