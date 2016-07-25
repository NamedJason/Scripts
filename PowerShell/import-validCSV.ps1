#Imports a CSV file, validating that it has the columns specified in the -requiredColumns parameter.  Throws a critical error if a required column is not found.
function import-ValidCSV
{
	param
	(
		[parameter(Mandatory=$true)]
		[ValidateScript({test-path $_ -type leaf})]
		[string]$inputFile,
		[string[]]$requiredColumns
	)
	$csvImport = import-csv $inputFile
	$inputTest = $csvImport | gm
	foreach ($requiredColumn in $requiredColumns)
	{
		if (!($inputTest | ? {$_.name -eq $requiredColumn}))
		{
			write-error "$inputFile is missing the $requiredColumn column"
			exit 10
		}
	}
	$csvImport
}
