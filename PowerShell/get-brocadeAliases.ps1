#Get a list of all Aliases from the specified Brocade Switch, then output a list of which of those Aliases correspond to currently active WWNs
#The -ReportAll switch will spit out a list of ALL discovered Aliases instead of just the active ones
param
(
	$user = "admin",
	$switch,
	$password,
	[switch]$reportAll
)
if ($plinkAliases = plink $user@$switch -pw $password 'alishow'){
	#Discover the Aliases from the switch
	$aliases = @()
	$aliases += "Type Alias WWN"
	for ($I=0;$I -lt $plinkAliases.count;$i++){
		if ($plinkAliases[$i].trim() -match "^alias"){
			$alias = $plinkAliases[$i]
			while ($plinkAliases[$i+1].trim() -match "^[\da-f]{2}:[\da-f]{2}:"){
				$alias = $alias + " " + $plinkAliases[$i+1]
				$i++
			}
			#Clean up the discovered Alias lines to make it easier to convert into an object
			$alias = $alias -replace "\s+"," "
			$aliases += $alias.trim()
		}
	}
	$aliases = $aliases | ConvertFrom-Csv -Delimiter " "
	#Generate output; either all of the found aliases or compare those aliases against the active WWNs from the nsshow command
	if ($reportAll){
		$aliases
	}
	else{
		$plinkWWNs = plink $user@$switch -pw $password 'nsshow'

		write-host "WWNs currently logged in to the switch:"
		"=" * "WWNs currently logged in to the switch:".length
		$output = @()
		foreach ($thisAlias in $aliases){
			if (($plinkWWNs | ? {$_ -match $thisAlias.WWN})){
				$output += $thisAlias
			}
		}
		$output
	}
}
else{
	write-host "Error, nothing was returned from 'plink $user@$switch'.`nIs 'plink' installed and accessible from the CLI?" -foregroundcolor red
}
