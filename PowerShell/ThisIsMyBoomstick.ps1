<# 
 	.SYNOPSIS 
 	Takes an array of file names (output from something like RV Tools) that are zombie VMDK files.  Outputs VMKFSTOOLS commands to rename the files and to delete the files
 	.EXAMPLE 
 	ThisIsmyBoomStick.ps1 -zombies E:\Temp\RV-Out.csv  -outRename E:\Temp\RenameCommands.txt -outDelete E:\Temp\DeleteCommands.txt
 	 
 	This command will read the E:\Temp\RV-Out.csv input file, which can be the raw output from the RVTools vHealth tab, parse through it for Zombie VMDK lines, and generate rename and delete VMKFSTOOLS commands for those identified files.
 	.NOTES 
 	The input file should be the output from the vHealth tab of the RVTools application.  It expects a CSV with 2 columns: Name and Message.  The message column must include the word Zombie and the Name column must be in the "[LUN] Folder/File.vmdk" syntax.
 #> 
param(
	$zombies,
	$outRename = "E:\Temp\RenameCommands.txt",
	$outDelete = "E:\Temp\DeleteCommands.txt"
)

$renameCommands = @()
$deleteCommands = @()
$zombieFiles = @()

$re1 = [regex]'\['
$re2 = [regex]'\]\ '


$zombies = import-csv $zombies

#Strip out the column headers and any non-vmdk lines from the RV Tools input
if ($zombies | gm message)
{
	$zombies = ($zombies | ? {$_.message -match 'Zombie'}).name
}
$zombies = $zombies | ? {$_ -like "*.vmdk"}
$zombies = $zombies | ? {!($_ -match "digest")}
$zombies = $zombies | ? {!($_ -match "checkpoint")}

#Convert the bracketed datastore syntax to a normal folder structure
$zombies | foreach {
	if ($_[0] -eq "[")
	{
		[string]$zombieString = $_
		$zombieString = $re1.replace($zombieString, '', 1)
		$zombieString = $re2.replace($zombieString, '/', 1)
		$zombieFiles += $zombieString
	}
}

$zombieFiles | foreach {
	$newName = """/vmfs/volumes/$($_.split('/')[0])/$($_.split('/')[1])/Unused-$($_.split('/') | select -last 1)"""
	$renameCommands += "vmkfstools -E ""/vmfs/volumes/$_"" $newName"
	$deleteCommands += "vmkfstools -U $newName"
}

$renameCommands > $outRename
$deleteCommands > $outDelete
echo "Complete.  Check $outRename and $outDelete for output."
