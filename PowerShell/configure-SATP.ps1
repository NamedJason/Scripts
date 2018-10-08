#Configure-SATP
#Configures appropriate SATP values for Pure storage arrays for all ESXi hosts that are in maintenance mode.
#Alternately, use parameters to set specific values for different arrays.
#Use the -vmhosts parameter to specify a regex to limit the scope of the script

param(
	$satp = "VMW_SATP_ALUA",
	$vendor = "PURE",
	$model = "FlashArray",
	$psp = "VMW_PSP_RR",
	$pspoption = "VMW_PSP_RR",
	$vmHosts = ""
)
#Get the ESXi Hosts that we're working on
$vmHostObjs = get-vmhost | ? {$_.name -match $vmHosts -and $_.ConnectionState -eq "Maintenance"}
foreach ($vmhost in $vmhostObjs){
	#Get the ESXCLI on the ESXi Host to configre the load balancing parameters
	$esxcli = $vmhost | Get-EsxCli -v2
	#Create the settings as per Pure's best practices
	$a = $esxcli.storage.nmp.satp.rule.add.createargs()
	$a.satp = $satp
	$a.vendor = $vendor
	$a.model = $model
	$a.psp = $psp
	$a.pspoption = $pspoption
	#Set those settings on the ESXi host
	$esxcli.storage.nmp.satp.rule.add.invoke($a)
}
