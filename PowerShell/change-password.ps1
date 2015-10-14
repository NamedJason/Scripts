#Change root passwords
#Usage: change-passwords.ps1 -oldPass <old root password> -passString <new root password>
param
(
	$passString = "StrongPassword" + '<_<">_>',
	$oldPass = "WeakPassword",
	$hostPrefix = "sac-esx",
	$hostSuffix = ".lab"
)

$hostsChanged = @()

$allHosts = get-vmhost $hostPrefix*$hostSuffix | sort

$allHosts | foreach {
	connect-viserver $_ -user root -password $oldPass
	set-vmhostaccount -useraccount (get-vmhostaccount root) -password $passString
	$hostsChanged += "Host $($_.name) has been assigned the password of $passString"
	cmd /C pause
}

$hostsChanged