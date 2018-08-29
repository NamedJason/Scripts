##### Invoke NSX REST API #####
param(
	$NSXserver = "NSXManagerFQDN",
	$Operation = "GET",
	$Endpoint = "/api/4.0/firewall/globalroot-0/status"
)
#Get credentials 
if (test-path -PathType leaf "NSXCreds.xml"){
	$Credentials = import-clixml NSXCreds.xml
}
else{
	$Credentials = Get-Credential -Credential $null
	#saves the credentials as a powershell secure credential object for future use
	$Credentials | export-clixml NSXCreds.xml
}

#Create authorization string and store in $head
$auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Credentials.UserName+ ":" + $Credentials.GetNetworkCredential().password))
$head = @{"Authorization"="Basic $auth"}

#Use TLS 1.2, had to add this line to address SSL/TLS secure channel error
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

#Create API call
#Create URI 
$Endpoint = $Endpoint.trim("/")
$uri = "https://$NSXserver/$Endpoint"
$NSXStatusXML = [xml](Invoke-WebRequest -Uri $uri -Headers $head -ErrorAction:Stop -Method $Operation -ContentType "application/xml")

#Analyze the results to see if any hosts are on the wrong rule set generation
if ($NSXStatusXML){
	$currentGeneration = $NSXStatusXML.firewallstatus.generationNumber
	$firewallStatus = $NSXStatusXML.firewallstatus.status
	write-host "Current Firewall Rule Generation is $currentGeneration"
	write-host "Current Firewall Status is $firewallStatus"
	$results = $NSXStatusXML.firewallstatus.clusterList.clusterstatus.hoststatuslist.hoststatus | select hostName,generationNumber,Status

	$outdatedHosts = $results | ? {$_.generationNumber -ne $currentGeneration}
	if ($outdatedHosts.count -gt 0){
		write-host -foregroundcolor "yellow" "The ESXi hosts are not using the current NSX Firewall rule set: ($currentGeneration)"
	}
	else {
		write-host -foregroundcolor "green" "All ESXi hosts are using the current NSX Firewall rule set."
	}
	$results
}
