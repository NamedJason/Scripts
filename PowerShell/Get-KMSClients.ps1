$days = 7

$relevantLogs = Get-EventLog -LogName "Key Management Service" | ? {$_.TimeGenerated -gt (get-date).adddays(-1 * $days)}
$activations = foreach ($log in $relevantLogs){
    $thisEntry = "" | select name,id
    $thisEntry.name,$thisEntry.id = $log.ReplacementStrings[3..4]
    $thisEntry
}

$results = foreach ($id in ($activations.id | sort -unique)){
    $result = "" | select id,names
    $result.id = $id
    $result.names = (($activations | ? {$_.id -eq $id}).name | sort -unique) -join ", "
    $result
}

$results
