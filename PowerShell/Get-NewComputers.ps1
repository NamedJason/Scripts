#Collects a list of all AD Computer objects created after $StartMonthsAgo months and before $EndMonthsAgo months ago.  Excludes computers based on OS and/or OU, accepting arrays of strings for each.
#Example: get-newComputers.ps1 -StartMonthsAgo 12 -endMonthsAgo 0 -notOS @("XP","7","10") -notOU @("Workstations","Laptops")
#Explanation: that example will get all AD Computer accounts created within the last 12 months that are not for Windows XP, Windows 7, or Windows 10 and are not in the Workstations or Laptops OUs.
param(
	$StartMonthsAgo = 24,
	$EndMonthsAgo = 12,
	$notOS = @("7","10"),
	$notOU = @("Workstations","Laptops"),
	$outFile
)
#Get all Computer objects from AD.  This can take a while...
$allComps = Get-ADComputer -Filter "*" -Properties Name,OperatingSystem,whenCreated,DistinguishedName,IPv4Address

#Generate Regular Expressions to exclude Windows X versions or systems in the specified OUs, or generate junk strings that will not match anything if no exclusions are desired.
if ($notOS){
	$notOSString = "Windows (" + ($notOS -join "|") + ")"
}
else {
	$notOSString = "thisshouldntmatchanythingohdontletitmatchanythign"
}
if ($notOU){
	$notOUString = "OU=(" + ($notOU -join "|") + ")"
}
else {
	$notOUString = "thisshouldntmatchanythingohdontletitmatchanythign"
}

#Filter the list of all computers based on OS and OU, then find the computers that were created within the specified timeframe
$allComps = $allComps | ? {!($_.OperatingSystem -match $notOSString) -AND !($_.DistinguishedName -match $notOUString)}
$targetComps = $allComps | ? {$_.whenCreated -gt (get-date).addmonths(-$startMonthsAgo) -AND $_.whenCreated -lt (get-date).addmonths(-$EndMonthsAgo)}

#Generate Output
if ($outFile){
	$targetComps | export-csv -noTypeInformation $outFile
}
else {
	$targetComps
}
