# test-passwords
# Prompts the user for a set of passwords, then tries those passwords, in order, against every specified server.  Generates a list of servers and which password (by number) worked for each.  Does not reveal passwords unless you use the -insecure switch.
param
(
	[string[]]$servers,
	[switch]$insecure
)
try{plink --help | out-null}
catch{throw "This script requires plink to function, please install it.  Ensure that the command ""plink --help"" executes successfully before continuing."}
$allPasswords = @()
(new-object -comObject wscript.shell).popup("Enter suspected root passwords; enter a blank password when done",0,"done",0x0) | out-null
while (($input = (Get-Credential "root")).getnetworkcredential().password){
	$allPasswords += $input
}
$output = @()
$j = 1
foreach ($server in $servers){
	write-progress -activity "Attempting to authenticate to servers" -status "Testing $server" -percentComplete ($j++ / $servers.count * 100) -id 1
	write-host "***Testing $server***"
	$outObj = "" | select name,password
	$outObj.name = $server
	$outObj.password = -1
	for($i=0;$i -lt $allPasswords.count;$i++){
		write-progress -activity "Attempting passwords" -status "Testing password #$($i+1)" -percentComplete ($i / $allPasswords.count * 100) -parentId 1
		if(plink "$($allPasswords[$i].getnetworkcredential().username)@$server" -pw ($allPasswords[$i].getnetworkcredential().password) -batch "ls"){
			write-host "$server uses known password #$($i+1)" -foregroundcolor green
			$outObj.name = $server
			$outObj.password = $i + 1
			break
		}
	}
	$output += $outObj
}
if ($insecure){
	$output | ? {$_.password -ge 0} | select name,@{Name="password";Expression={$allPasswords[$_.password - 1].getnetworkcredential().password}}
	$output | ? {$_.password -lt 0} | select name,@{Name="password";Expression={"UNKNOWN"}}
}
else{
	$output
}
