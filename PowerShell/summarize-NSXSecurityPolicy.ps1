#summarize-NSXSecurityPolicy.ps1
#Requires -modules PowerNSX
#Creates a table that summarizes all of the firewall rules that are defined in NSX Security Policies
#Run this after connecting to your NSX Server via the connect-NXSServer cmdlet
$allPolicies = Get-NsxSecurityPolicy
$report = foreach ($policy in $allPolicies){
	# Process all of the rules in the policy
	foreach ($action in ($policy.actionsByCategory | ? {$_.category -eq "firewall"}).action){
		$objFirewallRule = "" | select PolicyName,PolicyDescription,RuleName,RuleDescription,Source,Destination,Services,Action
		$objFirewallRule.PolicyName = $policy.name
		$objFirewallRule.PolicyDescription = $policy.Description
		$objFirewallRule.RuleName = $action.name
		$objFirewallRule.RuleDescription = $action.description
		$objFirewallRule.Services = @()
		$objFirewallRule.Services += $action.applications.application.name
		$objFirewallRule.Services += $action.applications.applicationgroup.name
		$objFirewallRule.Services = ($objFirewallRule.Services | sort -unique) -join ", "
		$objFirewallRule.Action = $action.action
		#Figure out what the source/destination of this rule is
		switch ($action.direction){
			"inbound"{
				$objFirewallRule.source = $action.secondarySecurityGroup.name -join ", "
				$objFirewallRule.destination = "This Group"
			}
			"outbound"{
				$objFirewallRule.destination = $action.secondarySecurityGroup.name -join ", "
				$objFirewallRule.source = "This Group"
			}
			"intra"{
				$objFirewallRule.source = "This Group"
				$objFirewallRule.destination = "This Group"
			}
			default{
				write-error "Unexpected firewall rule direction: $($action.direction)"
			}
		}
		# Put the word "any" where it needs to be
		$properties = @("source","destination","services")
		foreach ($property in $properties){
			if (!($objFirewallRule.$property)){$objFirewallRule.$property = "any"}
		}
		# Return the firewall rule object to the report variable
		$objFirewallRule
	}
}
$report
