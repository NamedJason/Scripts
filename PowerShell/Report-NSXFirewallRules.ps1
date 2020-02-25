#Report NSX Firewall Rules
$sections = get-nsxfirewallsection
$report = foreach ($section in $sections){
	foreach ($rule in $section.rule){
		$objRule = "" | select section,ruleName,ruleID,ruleSource,ruleDestination,ruleService,ruleAppliedTo
		$objRule.section = $section.name
		$objRule.ruleName = $rule.name
		$objRule.ruleID = $rule.id
		$objRule.ruleSource = $rule.sources.source.name -join ", "
		$objRule.ruleDestination = $rule.destinations.destination.name -join ", "
		$objRule.ruleService = $rule.services.service.name -join ", "
		$objRule.ruleAppliedTo = $rule.appliedToList.appliedTo.name -join ", "
		
		$objRule
	}
}
$report
