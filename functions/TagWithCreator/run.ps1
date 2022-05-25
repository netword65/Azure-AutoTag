param($eventGridEvent, $TriggerMetadata)

$caller = $eventGridEvent.data.claims.'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'
if ($null -eq $caller) {
    if ($eventGridEvent.data.authorization.evidence.principalType -eq "ServicePrincipal") {
        $caller = (Get-AzADServicePrincipal -ObjectId $eventGridEvent.data.authorization.evidence.principalId).DisplayName
        if ($null -eq $caller) {
            Write-Host "MSI may not have permission to read the applications from the directory"
            $caller = $eventGridEvent.data.authorization.evidence.principalId
        }
    }
}
Write-Host "----------->Caller: $caller"
$resourceId = $eventGridEvent.data.resourceUri
Write-Host "----------->ResourceId: $resourceId"

if (($null -eq $caller) -or ($null -eq $resourceId)) {
    Write-Host "----------->ResourceId or Caller is null"
    exit;
}

#$ignore = @("providers/Microsoft.Resources/deployments", "providers/Microsoft.Resources/tags", "providers/Microsoft.Network/frontdoor")
$ignore = @("providers/Microsoft.Resources/deployments", "providers/Microsoft.Resources/tags", "providers/Microsoft.Network/frontdoor", "providers/microsoft.insights/autoscalesettings", "Microsoft.Compute/virtualMachines/extensions", "Microsoft.Compute/restorePointCollections", "Microsoft.Classic")

foreach ($case in $ignore) {
    if ($resourceId -match $case) {
        Write-Host "----------->Skipping event as resourceId contains: $case"
        exit;
    }
}

$ignoreCaller = @("autotagfnc")

foreach ($case in $ignoreCaller) {
    if ($caller -match $case) {
        Write-Host "----------->Skipping event as caller contains: $case"
        exit;
    }
}



$tags = (Get-AzTag -ResourceId $resourceId).Properties.TagsProperty
if ($null -eq $tags) {
    $tags = @{}
}

Write-Host $tags

try{
    if (!($tags.ContainsKey('_Creator'))){
        $tag = @{
            _Creator = $caller
        }
        Update-AzTag -ResourceId $resourceId -Operation Merge -Tag $tag
        Write-Host "----------->Added creator tag with user: $caller"
    }
    else {
        Write-Host "----------->Tag already exists (_Creator)"
    }

    if (!($tags.ContainsKey('_CreationDate'))){   
        #$creationDate = $eventGridEvent.data.eventTimestamp
        #if($creationDate.Length -le 1){
         #   $creationDate = (Get-Date -Format yyyy-MM-dd)
        #}
        $cstzone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Central Europe Standard Time")
        $csttime = [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(),$cstzone)
        $tag2 = @{
            _CreationDate = (Get-Date $csttime -Format "yyyy-MM-dd HH:mm") #(Get-TimeZone -ListAvailable) | ogv
        }
        Update-AzTag -ResourceId $resourceId -Operation Merge -Tag $tag2
        Write-Host "----------->Added creation date"
    }
    else {
        Write-Host "----------->Tag already exists (_CreationDate)"
    }
} catch {
    $ErrorMessage = $_.Exception.message
    write-host ('Error assigning tags:' + $ErrorMessage)
}

#Write-Host "----------->!!!DATA:"
#$eventGridEvent.data.claims
#Write-Host $eventGridEvent.data.eventTime #does not exist

Write-Host "----------->!!!operationName:"
Write-Host $eventGridEvent.data.operationName
