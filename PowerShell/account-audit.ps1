<#
	.SYNOPSIS
	Script to audit an Active Directory domain and output all user accounts, their group membership and vCenter Roles.
	
	.DESCRIPTION
	This script queries Active Directory and examines every account within a given OU (the root may be specified, but be careful as it might take a long time...).  It then creates a CSV that lists every user account, what groups that account belongs to, and what Roles have been defined that apply to that account in vCenter.  It compares that CSV against the last one that it generated and creates a Delta report, which is emailed to the specified administrator.
	
	This script requires 3 additional powershell extensions in order to function: Microsoft RSAT Active Directory PowerShell Module, VMware PowerCLI Snapin, Quest ActiveRoles PowerShell Snapin.
	
	.PARAMETER MaxToKeep
	The maximum number of full reports to keep.  An unlimited number of delta reports will be kept for auditing purposes.

	.PARAMETER vCenters
	The DNS Resolvable name or IP Address of the vCenter(s) to query.

	.PARAMETER outFolder
	The path to the folder (with a trailing backslash) to which the reports should be written.

	.PARAMETER outFile
	The name of the CSV (with no extension) to write.

	.PARAMETER outDelta
	The name of the delta log file (with no extension) to write.

	.PARAMETER mailToAccount
	The email addrss to send the report to.

	.PARAMETER mailSubject
	The subject line for the audit report.

	.PARAMETER mailSMTP
	The SMTP Relay to route the email through.

	.PARAMETER mailFromAccount
	The account from which the email will be sent.

	.PARAMETER searchRoot
	The Active Directory path in which to search for accounts.

	.PARAMETER searchString
	A string to match for the search - wildcards are accepted.
	
	.EXAMPLE
	account-audit.ps1
	
	This will run the script with all default settings, as specified in the param block.
	
	.EXAMPLE
	restart-DT.ps1 -searchRoot "domain.local/OU" -SearchString "admin*"
	
	This will only search within the specified OU, for all accounts that begin with "admin" in their account name, first name or last name field.
	
	.LINK
	http://virtuallyjason.blogspot.com
	
	Author: Jason Coleman
	Last Modified: 10/11/2013
#>
param
(
	[int]$MaxToKeep = 3,
	[string]$DC = "myDC1",
	[string[]]$vCenters = @("myvCenter.company.local"),
	[string]$outFolder = "C:\Reports\",
	[string]$outFile = "AuditAccounts",
	[string]$outDelta = "AuditDelta",
	[string]$mailToAccount = "administrator@company.local",
	[string]$mailSubject = "Account Audit Report",
	[string]$mailSMTP = "SMTPRelay.company.local",
	[string]$mailFromAccount = "vcenter@company.local",
	[string]$searchRoot = "company.local/OU",
	[string]$searchString = "*"
)
if (!(get-pssnapin Quest* -registered))
{
	write-output "Please download the Quest ActiveRoles PowerShell cmdlets from http://www.quest.com/powershell/activeroles-server.aspx"
	Return
}
if (!(get-pssnapin VMware* -registered))
{
	write-output "Please download the VMware PowerCLI cmdlets from https://my.vmware.com/web/vmware/details?productId=352&downloadGroup=PCLI550"
	Return
}
If (!((get-module -listavailable) -like "ActiveDirectory"))
{
	write-output "Please install RSAT and the ActiveDirectory PS Module Windows Feature"
	Return
}
import-module ActiveDirectory
Add-PSSnapin VMware.VimAutomation.Core
Add-PSSnapin Quest.ActiveRoles.ADManagement
connect-VIServer $vCenters

function collectUsers
{
	$colAccounts = @()
	#Uses Get-QADuser in order to detect nested group membership
	$allUsers = get-qaduser -service $DC -SearchRoot $searchRoot $searchString | Select AllMemberOf,Name,Description,SamAccountName,Domain
	write-output "Collecting user accounts..."
	foreach ($thisUser in $allUsers)
	{
		$colRoles = @()
		$objAccount = New-Object System.Object
		$objRole = New-Object System.Object
		$allGroups = $thisUser.AllMemberOf
		[string]$strAllGroups = ""
		[string]$strAllRoles = ""
		$Domain = $thisUser.Domain
		#Deals with the user's groups
		$i = 0
		foreach ($thisGroup in $allGroups)
		{
			#Cleans up the LDAP formatting to get just group names
			If ($thisGroup)
			{
				$allGroups[$i] = $thisGroup.Substring(0,$thisGroup.indexof(",")) -replace "CN=", ""
				#Creates a string of all discovered Groups for output into CSV
				$strAllGroups += "{$($allGroups[$i])}"
			}
			#Captures any vCenter Roles assigned to the user's Groups
			$colRoles += Get-VIPermission | where {$_.Principal -eq "$Domain$($allGroups[$i])"} | select Role, Entity
			$i++
		}

		$objAccount | Add-Member -type NoteProperty -name Name -value $thisUser.Name
		$objAccount | Add-Member -type NoteProperty -name Description -value $thisUser.Description
		$objAccount | Add-Member -type NoteProperty -name Groups -value $allGroups
		$objAccount | Add-Member -type NoteProperty -name strGroups -value $strAllGroups
		#Captures any vCenter Roles assigned directly to the User
		$colRoles += Get-VIPermission | where {$_.Principal -eq "$Domain$($thisUser.SamAccountName)"} | select Role, Entity

		#Creates a string of all discovered Roles for output into CSV
		foreach ($thisRole in $colRoles)
		{
			$strAllRoles += $thisRole
		}
		$objAccount | Add-Member -type NoteProperty -name Roles -value $colRoles
		$objAccount | Add-Member -type NoteProperty -name strRoles -value $strAllRoles
		$colAccounts += $objAccount
	}

	write-output "Managing reports..."
	# Remove oldest report
	$i = $MaxToKeep
	if (!(test-path $outFolder))
	{
		write-output "Creating folder $outFolder"
		new-item -itemType directory -path $outFolder | out-null
	}
	if (test-Path "$outFolder$outFile$i.csv")
	{
		remove-item "$outFolder$outFile$i.csv"
	}
	$i--
	# Archive existing reports
	while ($i -gt 0)
	{
		if (test-Path "$outFolder$outFile$i.csv")
		{
			$j = $i + 1
			rename-item "$outFolder$outFile$i.csv" "$outFolder$outFile$j.csv"
		}
		$i--
	}
	$i = 1
	#Generates new report
	$colAccounts | Select Name,Description,strGroups,strRoles | Export-Csv "$outFolder$outFile$i.csv" -noTypeInformation

}

function generateDelta
{
	$colNewUsers = @()
	$colDelUsers = @()
	$colAccountDelta = @()
	$i = 1
	$j = 2
	write-output "Performing delta comparison..."
	$strToday = get-date
	$colAccountDelta += "----------"
	$colAccountDelta += "Account Audit Report for $strToday"
	$colAccountDelta += "----------"
	$colAccountDelta += ""
	#Find differences
	if (test-path "$outFolder$outFile$j.csv")
	{
		$currentReport = import-csv "$outFolder$outFile$i.csv"
		$previousReport = import-csv "$outFolder$outFile$j.csv"
		#Look for changes in the new file
		foreach ($currentLine in $currentReport)
		{
			$previousLine = $previousReport | where {$_.Name -eq $currentLine.Name}
			if ($previousLine.Name.length -gt 0)
			{
				#Report Changed Users
				if (($previousLine.strGroups -ne $currentLine.strGroups) -or ($previousLine.strRoles -ne $currentLine.strRoles))
				{
					$colAccountDelta += "----------"
					$colAccountDelta += "Account Modified: $($currentLine.Name)"
					$colAccountDelta += "----------"
					If ($previousLine.strGroup -ne $currentLine.strGroups)
					{
						$colAccountDelta += "AD Group Membership Changes:"
						$colAccountDelta += ""
						$arrCurGroups = $currentLine.strGroups -split "}"
						$arrPreGroups = $previousLine.strGroups -split "}"
						#Detect New Groups
						foreach ($currentGroup in $arrCurGroups)
						{
							if ($arrPreGroups -notcontains $currentGroup)
							{
								$colAccountDelta += "    Group added: $($currentGroup.trimstart('{'))"
							}
						}
						#Detect Removed Groups
						foreach ($previousGroup in $arrPreGroups)
						{
							if ($arrCurGroups -notcontains $previousGroup)
							{
								$colAccountDelta += "    Group removed: $($previousGroup.trimstart('{'))"
							}
						}
						$colAccountDelta += ""					
					}
					If ($previousLine.strRoles -ne $currentLine.strRoles)
					{
						$colAccountDelta += "vCenter Role Changes:"
						$colAccountDelta += ""
						$arrCurRoles = $currentLine.strRoles -split "@"
						$arrPreRoles = $previousLine.strRoles -split "@"
						#Detect New Roles
						foreach ($currentRole in $arrCurRoles)
						{
							if ($arrPreRoles -notcontains $currentRole)
							{
								$colAccountDelta += "    Role added: $currentRole"
							}
						}
						#Detect Removed Roles
						foreach ($previousRole in $arrPreRoles)
						{
							if ($arrCurRoles -notcontains $previousRole)
							{
								$colAccountDelta += "    Role removed: $previousGroup"
							}
						}
						$colAccountDelta += ""					
					}
					$colAccountDelta += "----------"
					$colAccountDelta += ""	
				}
			}
			#Collect New Users
			else
			{
				$colNewUsers += $currentLine
			}
		}
		#Collect Deleted users
		foreach ($previousLine in $previousReport)
		{
			$currentLine = $currentReport | where {$_.Name -eq $previousLine.Name}
			if ($currentLine.Name.length -lt 1)
			{
				$colDelUsers += $previousLine
			}
		}
		#Sort the new and deleted users lists by user name
		$colNewUsers = $colNewUsers | sort -property Name
		$colDelUsers = $colDelUsers | sort -property Name
		#Report the new users
		foreach ($thisLine in $colNewUsers)
		{
			$colAccountDelta += "----------"
			$colAccountDelta += "New Account Added: $($thisLine.Name) - $($thisLine.Description)"
			$colAccountDelta += "----------"
			$colAccountDelta += "    Configured AD Groups:"
			$colAccountDelta += ""
			$colAccountDelta += $thisLine.strGroups
			$colAccountDelta += ""
			$colAccountDelta += "    Configured vCenter Roles:"
			$colAccountDelta += ""
			$colAccountDelta += $thisLine.strRoles
			$colAccountDelta += "----------"
			$colAccountDelta += ""
		}
		#Report the deleted users
		foreach ($thisLine in $colDelUsers)
		{
			$colAccountDelta += "----------"
			$colAccountDelta += "Account Deleted: $($thisLine.Name) - $($thisLine.Description)"
			$colAccountDelta += "----------"
		}
	}
	write-output "Sending report email..."
	$nl = [Environment]::NewLine
	$strAccountDelta = $colAccountDelta -join $nl
	$date = get-date
	$strAccountDelta | out-file "$outFolder$outDelta-$($date.year)$($date.month)$($date.day)$($date.hour)$($date.minute).txt"
	send-mailmessage -to $mailToAccount -subject $mailSubject -body $strAccountDelta -smtpserver $mailSMTP -from $mailFromAccount -attachments "$outFolder$outFile$i.csv"
}

#Create the Reports
collectUsers
#Calculate the delta and send the email
generateDelta

#Clean up when done
disconnect-VIServer $vCenters
Remove-PSSnapin VMware.VimAutomation.Core
Remove-PSSnapin Quest.ActiveRoles.ADManagement