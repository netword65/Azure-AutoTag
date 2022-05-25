$resourceGroupName = "AutoTag-rg"                # <-- REPLACE the variable values with your own values.
$location = "westeurope"                         # <-- Ensure that the location is a valid Azure location
$storageAccountName = "saautotag" + (Get-Date -Format "yyyyMMdd")  # <-- Ensure the storage account name is unique
$appServicePlanName = "autotag-asp"              # <--
$appInsightsName = "autotag-insight"             # <--
$functionName = "autotag-fnc"                    # <--

New-AzResourceGroup -Name $resourceGroupName -Location $location -Force -Verbose

$params = @{
    storageAccountName = $storageAccountName.ToLower()
    appServicePlanName = $appServicePlanName
    appInsightsName    = $appInsightsName
    functionName       = $functionName
}

$output = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile .\azuredeploy.json -TemplateParameterObject $params -Verbose

New-AzRoleAssignment -RoleDefinitionName "Reader" -ObjectId $output.Outputs.managedIdentityId.Value -ErrorAction SilentlyContinue -Verbose
New-AzRoleAssignment -RoleDefinitionName "Tag Contributor" -ObjectId $output.Outputs.managedIdentityId.Value -ErrorAction SilentlyContinue -Verbose

Push-Location
Set-Location ..\functions
Compress-Archive -Path * -DestinationPath ..\environment\functions.zip -Force -Verbose
Pop-Location

$file = (Get-ChildItem .\functions.zip).FullName

Publish-AzWebApp -ResourceGroupName $resourceGroupName -Name $functionName -ArchivePath $file -Verbose -Force

Remove-Item $file -Force
