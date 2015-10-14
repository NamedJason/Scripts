#This script nags people to submit their documentation.  
#It checks a file share to see if new files exist; if no new file shave been added to the share since the last execution of the script, it sends out a reminder to the specified individuals.
#It will not send a nag message if the file count meets or exceeds the -expectedFiles value.
#If new files exist in the share, it sends them as an attachment to the specified individuals (even if there are more than -expectedFiles) instead of sending a nag message.

param
(
	#This XML file stores the list of documents from the previous execution of the script, to determine what files are new
	$xmlFile = "C:\Temp\layer-docs.xml",
	#This is the document share that the script checks for new files
	$docShare = "\\fileServer\documentation",
	$mailFromAccount = "nag@company.com",
	#List of email addresses to send the Nag message to
	$mailNagToAccount = @("naged1@company.com","naged2@company.com"),
	#List of email addresses to send new files to
	$mailNewToAccount = @("nag@company.com"),
	#List of email addresses (managers) to CC on Nag message
	$mailNagCcAccount = @("manager@company.com"),
	#SMTP Relay to use to send the emails
	$mailSMTP = "smtpRelay",
	$mailSubject = "Project Documentation Reminder",
	#Email message body for when new files are found
	$strNewMailMessage = "There are new files!",
	#Email message body for when nagging is required
	$strNagMailMessage = "Hey guys - I see that our document share ('$docShare') does not have any additional project documents in it.  Please include your documentation at your earliest convenience.  Thanks!",
	#The total number of files that will exist in the document share when documentation is completed.  The script does not nag if there are at least this many files.
	$expectedFiles = 6
)

$newFiles = @()
$curFiles = Get-ChildItem $docShare -name

#Ensure that there is a record from the previous run against which to compare the current results.
if (Test-Path $xmlFile)
{
	#Build a list of all new files in the document directory
	$prevFiles = Import-Clixml -Path $xmlFile
	foreach ($thisFile in $curFiles)
	{
		if (!($prevFiles -contains $thisFile))
		{
			$newFiles += "$fileStore\$thisFile"
		}
	}
	#Email any new files to the designated email addreses
	if ($newFiles.count -gt 0)
	{
		echo "Send the new file for review"
		send-mailmessage -to $mailNewToAccount -subject $mailSubject -body $strNewMailMessage -smtpserver $mailSMTP -from $mailFromAccount -Attachments $newFiles
	}
	else
	{	
		#If there are fewer than the desired number of files, send the nag message.  Otherwise do nothing.
		if ((get-childitem $docShare).count -lt $expectedFiles)
		{
			echo "Send the Nag Message"
			send-mailmessage -to $mailNagToAccount -cc $mailNagCcAccount -subject $mailSubject -body $strNagMailMessage -smtpserver $mailSMTP -from $mailFromAccount
		}
		else
		{
			echo "More than $expectedFiles files were found, no message sent."
		}		
	}
}
$curFiles | Export-Clixml -Path $xmlFile