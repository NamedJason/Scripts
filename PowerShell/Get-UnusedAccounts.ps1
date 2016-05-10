#Gets a list of Active Directory accounts that haven't been logged into for a specified number of days.  This queries each of the specified Domain Controllers, as each one only stores the last time that it authenticated a given account.
#Authors: Jason Coleman (virtuallyjason.blogspot.com), Bob Westendorf
#Usage: Get-UnusedAccounts -Days <Number of days since last logon> -DCName <name of DC to query, Wild-cards accepted> -SearchBase <LDAP Path to search> -Filter <Active Directory Query String>
#Example: Get-UnusedAccounts -Days 90 -DCName SacDC* -SearchBase "ou=MyUsers,dc=Company,dc=Local" -Filter *
Param
(
	$Days = 90,
	$DCName = "SacDC*",
	$SearchBase = "ou=MyUsers,dc=Company,dc=Local",
	$Filter = "*"
)

$OutUsers = @()
ForEach ($ADUser in (Get-ADUser -Filter $Filter -SearchScope subtree -SearchBase $SearchBase -Properties SamAccountName,Description,WhenCreated | ? {$_.Enabled -eq $True})) 
{
    #Creates a dummy user object with properties to be filled later
    $ObjUser = "" | Select SamAccountName,Description,WhenCreated,LastLogon,LastLogonInt
	
    #Sets the baseline logon date as the day that the account was created, to protect new accounts that have never logged in
    $UserLastLogon = $ADUser.WhenCreated.TofileTime()

    #Check each DC for when it last authenticated the user, storing the latest logon in $UserLastLogon
    ForEach ($ThisDC in (Get-ADDomainController -Filter {Name -like $DCName} | Select -ExpandProperty Name))
    {
        $User = Get-ADUser -Identity $ADUser -Server $ThisDC -Properties LastLogon
        If ($User.LastLogon -gt $UserLastLogon)
        {
            $UserLastLogon = $User.LastLogon
        }
    }    

    #Format the date as a string for output
    If ($UserLastLogon -eq $ADUser.WhenCreated.TofileTime())
    {
        $UserLastLogonOutput = "Never"
    }
    Else
    {
        $UserLastLogonOutput = [datetime]::FromFileTime($UserLastLogon).ToString('g')
    }

    #Fills in the properties on the dummy user object
    $ObjUser.SamAccountName = $ADUser.SamAccountName
    $ObjUser.Description = $ADUser.Description
    $ObjUser.WhenCreated = $ADUser.WhenCreated
    $ObjUser.LastLogonInt = $UserLastLogon
    $ObjUser.LastLogon = $UserLastLogonOutput

    #Adds the user object to the output array
    $OutUsers += $ObjUser 
}

#Returns only those users who haven't logged in for $Days days or more
$OutUsers | ? {(Get-Date).adddays(-$Days) -gt [datetime]::FromFileTime($_.LastLogonInt)}  | Select SamAccountName,Description,WhenCreated,LastLogon
