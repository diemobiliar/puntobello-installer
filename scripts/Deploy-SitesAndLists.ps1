Import-Module /usr/local/bin/login.psm1 -Force

$global:SPFX_CONFIG_SITE="pb_config"

if($null -eq (Get-PnPTenantSite -Url "https://$($global:M365_TENANTNAME).sharepoint.com/sites/$($global:SPFX_CONFIG_SITE)" -Connection $global:cnAdmin -ErrorAction SilentlyContinue)){
    New-PnPSite -Type "CommunicationSite" -Title "PuntoBello Configuration" -Url "https://$($global:M365_TENANTNAME).sharepoint.com/sites/$($global:SPFX_CONFIG_SITE)" -Lcid 1031 -Owner $global:adminUser -Connection $global:cnAdmin
}

$scriptControl = Get-Content ./spo/scripts.json | ConvertFrom-Json
$scripts = $scriptControl.scripts | Sort-Object SortOrder | Select-Object scriptName
foreach ($script in $scripts) {
    $i++
    Write-Host "*********************************************************************"
    Write-Host "Running $($script.scriptName) ($($i)/$($scripts.count))"
    Write-Host "*********************************************************************"
    Invoke-Expression -Command "$($script.scriptName)"
}