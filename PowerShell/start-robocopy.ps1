#Kicks off the Robocopy jobs
#.\start-robocopy.ps1 -foldersList D:\temp\FoldersList.csv -logFolder D:\temp\Log
param(
	[ValidateScript({
		if ($_ -notmatch "\.csv"){
			throw "The foldersList must be the path to a CSV file."
		}
		if (((import-csv $_ | gm |? {$_.MemberType -eq "NoteProperty"}).name |sort) -join "," -ne "destinationDrive,destinationUNC,sourceDrive,sourceUNC"){
			throw "The foldersList must be a CSV file with these columns: sourceDrive, destinationDrive, sourceUNC, destinationUNC."
		}
		$TRUE
	})]
	[string]$foldersList,
	[ValidateScript({
		if ($_ -notmatch "\.csv"){
			throw "The drivesList must be the path to a CSV file."
		}
		if (((import-csv $_ | gm |? {$_.MemberType -eq "NoteProperty"}).name |sort) -join "," -ne "Credentials,DriveLetter,UNCPath"){
			throw "The foldersList must be a CSV file with these columns: Credentials, DriveLetter, UNCPath.  Credentials is a file path to an xml file which will store encrypted crednetials to mount the drive."
		}
		$TRUE
	})]
	[string]$drivesList,
	[ValidateScript({Test-Path $_ -PathType 'Container'})]
	[string]$logFolder
)
$copyJobs = import-csv $foldersList

# $Drives = "DriveLetter,UNCPath,Credentials
# L,\\Dart\Test,D:\temp\creds-1.xml" | convertfrom-csv
$drives = import-csv $drivesList
#Map the drives
foreach ($drive in $Drives){
	try {
		$creds = import-clixml $drive.credentials
	}
	catch {
		$creds = get-credential -message "Enter credentials for $($drive.UNCPath)"
		$creds | export-clixml $drive.credentials
	}
	New-PSDrive -psProvider "FileSystem" -name $drive.DriveLetter -root $drive.UNCPath -credential $creds -errorAction stop
}

#Run the robocopies
$logFolder = $logFolder.trim("\")
$today = (get-date -Format "yyyy-MM-dd-HHmm")
$logPath = "$logFolder\" + $today + "-Robocopy.log"
foreach ($copyJob in $copyJobs){
	Robocopy.exe $copyJob.sourceDrive $copyJob.destinationDrive /e /zb /fft /copy:DAT /mir /r:1 /w:1 /MT:8 /v /ns /np /log+:$logPath /xd '"$Recycle.bin"' '"System Volume Information"' .etc lost+found
}

#Create log errors file with summary of the robocopy logs
$jobSummary = @()
$jobSummary += (get-content $logPath | ? {$_ -match "^(\d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2})?[ \t]*(Error|ERROR|error)"}).trim()
$filesLines = get-content $logPath | ? {$_ -match "Files : +\d"}
$dirLines = get-content $logPath | ? {$_ -match "Dirs : +\d"}
$failedFiles = ($filesLines | % {($_ -split " +")[7]} | measure-object -sum).sum
$failedDirs = ($dirLines | % {($_ -split " +")[7]} | measure-object -sum).sum
$copiedFiles = ($filesLines | % {($_ -split " +")[4]} | measure-object -sum).sum
$copiedDirs = ($dirLines | % {($_ -split " +")[4]} | measure-object -sum).sum
$skippedFiles = ($filesLines | % {($_ -split " +")[5]} | measure-object -sum).sum
$skippedDirs = ($dirLines | % {($_ -split " +")[5]} | measure-object -sum).sum
$jobSummary += "-" * 50
$jobSummary += "Total Files Copied: " + $copiedFiles
$jobSummary += "Total Directories Copied: " + $copiedDirs
$jobSummary += "Total Files Skipped: " + $skippedFiles
$jobSummary += "Total Directories Skipped: " + $skippedDirs
$jobSummary += "Total File Failures: " + $failedFiles
$jobSummary += "Total Directory Failures: " + $failedDirs
$jobSummary | set-content ("$logFolder\" + $today + "-Summary.log")

