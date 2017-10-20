#Repopulate data in custom fields
#Input file is a CSV that contains a Name column with the VM Name, and a column that corresponds with each MeaningfulField
param
(
	$source = "C:\temp\VMs.csv",
	$meaningfulFields = @("Solution Admin","Solution Name","Solution Owner")
)
#Import the source file that contains a VM Name column as well as columns for all of the meaningful fields
$sourceList = @()
$sourceList += import-csv $source
$allVMs = get-vm
#Go through each line of the source file, checking if the VM has any fields that need to be updated
$i = 1
foreach ($line in $sourceList){
	write-progress -Activity "Restoring Custom Field Data" -Status "Working on $($line.name)" -PercentComplete($i++ / $sourceList.count * 100)
	if ($vm = $allVMs | ? {$_.name -eq $line.name}){
		foreach ($meaningfulField in $meaningfulFields){
			if ($line.$meaningfulField -and ($vm | Get-Annotation -CustomAttribute $meaningfulField).value -ne $line.$meaningfulField){
				#if the VM exists and the data for the meaningful field is different on the VM than it is in the file, change the VM data.
				$vm | Set-Annotation -CustomAttribute $meaningfulField -Value $line.$meaningfulField
			}
		}
	}
}
