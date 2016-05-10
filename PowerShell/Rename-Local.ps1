# Renames local datastores on ESXi hosts to use the hostname plus a specified suffix.
# Usage: Rename-Local.ps1 -cluster <Cluster name> -suffix <Datastore Suffix>
# Website: http://virtuallyjason.blogspot.com/
# Reference: http://virtuallyjason.blogspot.com/2015/12/renaming-esxi-host-local-datastores-by.html
# Original script by VMNick0 at http://www.pcli.me/?p=25
[cmdletbinding(SupportsShouldProcess=$True)]
param(
  $cluster = "sac-cluster",
  $suffix = "-local"
)
get-cluster $cluster | get-vmhost | % {
  $_ | get-datastore | ? {$_.name -match "^datastore1( \(\d+\))?$"} | set-datastore -name "$($_.name.split(".")[0])$suffix"
}
