#Recreates user to desktop assignments
#Notes: the -UserMappings file is the output CSV from View Administrator, by right clicking on the desktops list and selecting "Export table contents".  Must have "Desktop Pool","User" and "Machine" columns.
#Notes: the -Desktops parameter should be a regex that matches all of the desktops that should be remapped, according to the file.  VDMAdmin seems to ignore commands that map a user to a desktop that they already have, but be careful anyway.
#Usage: remap-desktops.ps1 -UserMappings <path to CSV> -Desktops <Regex for the desktops to remap>
param(
	[validateScript({test-path $_ -pathType leaf})]
	[alias("u")]
	$UserMappings,
	[alias("d")]
	$Desktops,
	[alias("r")]
	[switch]$ReportOnly
)

$global = import-csv $UserMappings
$columns = @("machine","Desktop Pool","user")

#Basic error checking - ensure that the file has the expected columns and remove any blank assignments (unassigned desktops)
foreach ($column in $columns)
{
	if (!($global | gm $column)){write-host -foreground "red" "Input file $UserMappings does not have the ""$column"" Column";exit}
}
$global = $global | ? {$_.user -ne ""}

#Assign the desktops to the appropriate users
$Report = @()

$global | ? {$_.machine -match $Desktops} | % {
	$Report += $_ | select machine,'Desktop Pool',user
	if (!($ReportOnly)){
	echo "Assigning $($_.machine) to $($_.user)"
	vdmadmin -L -d $_.'Desktop Pool' -m $_.machine -u $_.user
	}
}

$Report | export-csv "actions.csv"
if ($ReportOnly){$Report}
