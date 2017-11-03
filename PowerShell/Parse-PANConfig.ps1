#Parse Palo Alto firewall config export XML into an array of PowerShell objects.
#Use: Parse-PANConfig.ps1 -vsys <String> -panConfigXML <xml>
# -vsys is the name of the vsys to be analyzed, leave it blank to analyze the whole firewall
# -panConfigXML is an XML object that contains the PAN configuration.  Use '[xml](get-content panConfig.xml)' to get the necessary PS Object.
param(
	$vsys = "",
	$panConfigXML
)
if ($panConfigXML.getType().name -ne "XmlDocument"){throw "panConfigXML requires an XML Object.  Use '[xml](get-content config.xml' to get an appropriate object."}
$output = @()
$vsysOfInterest = (($panConfigXML | select-xml -xpath "//*[contains(@name,""$vsys"")]").node | ? {$_.'pre-rulebase' -or $_.'post-rulebase' -or $_.rulebase})
foreach ($thisVsys in $vsysOfInterest){
	$i = 0
	$rules = @()
	$rules += $thisVsys.'pre-rulebase'.security.rules.entry | ? {$_}
	$rules += $thisVsys.'post-rulebase'.security.rules.entry | ? {$_}
	$rules += $thisVsys.'rulebase'.security.rules.entry | ? {$_}
	foreach ($rule in $rules){
		$propHashtable = @{}
		$propHashtable.add("VSys",($thisVsys.name -join ", "))
		$propHashtable.add("Name",($rule.name -join ", "))
		$propHashtable.add("From",($rule.from.member -join ", "))
		$propHashtable.add("To",($rule.to.member -join ", "))
		$propHashtable.add("Source-Negate",($rule.'negate-source' -join ", "))
		$propHashtable.add("Source",($rule.source.member -join ", "))
		$propHashtable.add("Destination-Negate",($rule.'negate-destination' -join ", "))
		$propHashtable.add("Destination",($rule.destination.member -join ", "))
		$propHashtable.add("Application",($rule.application.member -join ", "))
		$propHashtable.add("Service",($rule.service.member -join ", "))
		$propHashtable.add("Action",($rule.action -join ", "))
		$propHashtable.add("RuleNumber",$i++)
		$outObj = new-object psobject -property $propHashtable
		$output += $outObj
	}
}
$output
