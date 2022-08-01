#Determines the smallest possible subnet that can contain the two given IP Addresses, then returns the subnet/CIDR value.
#extract-CIDR -addressPair @("Address1","Address2")
param (
	[string[]]$addressPair
)
#verify that the input is 2 IP Addresses
try {
	[ipaddress]$addressPair[0] | out-null
	[ipaddress]$addressPair[1] | out-null
} catch {
	throw $_
}
#Convert the addresses to Binary
$binNetStart = ($addressPair[0] -split "\." | % {[convert]::tostring($_,2).padleft(8,"0")}) -join ""
$binNetEnd = ($addressPair[1] -split "\." | % {[convert]::tostring($_,2).padleft(8,"0")}) -join ""
#Discover an appropriate netmask
$binNetMask = for ($i = 0; $i -le 32; $i++){
	if ($binNetStart[$i] -eq $binNetEnd[$i]){
		"1"
	} else {
		"0"
	}
}
$binNetMask = $binNetMask -join ""
#Convert the netmask to CIDR
if ($binNetMask -match "^(1+)"){
	$CIDR = $matches[1].length
}
#Figure out the start of the subnet
$subBinary = ($binNetStart[0..($CIDR -1)] -join "").padRight(32,"0")
$sub = for($i = 0;$i -lt 30;$i = $i + 8){
	[convert]::toInt32(($subBinary[$i..($i+7)] -join ""),2)
}
#Return the results
($sub -join ".") + "/" + $CIDR
