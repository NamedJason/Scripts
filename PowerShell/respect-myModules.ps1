param(
	$langsPath = $ENV:APPDATA + "\Notepad++\langs.xml",
	$modules = @("vmware.PowerCLI","powerVRNI","powerNSX")
)
#Get the current languages file
$languages = [xml](get-content $langsPath)
$cmdlets = (($languages.notepadPlus.languages.language | ? {$_.name -eq "powershell"}).keywords | ? {$_.name -eq "instre2"}).'#text' -split " "

#add the commands from the specified modules
foreach ($module in $modules){
	write-host "importing $module"
	import-module $module
	if (get-module $module){
		if ($module -like "*.*"){
			$cmdlets += (get-command -module "$($module.split(".")[0])*").name
		}
		else{
			$cmdlets += (get-command -module $module).name
		}
	}
}
$cmdlets = ((($cmdlets | sort) | select -unique) -join " ").tolower()
(($languages.notepadPlus.languages.language | ? {$_.name -eq "powershell"}).keywords | ? {$_.name -eq "instre2"}).'#text' = $cmdlets
$languages.save($langsPath)