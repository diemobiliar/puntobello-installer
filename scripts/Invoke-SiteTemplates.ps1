function Invoke-SiteTemplate {
    param (
      [string]$siteUrl,
      [string]$templatePath,
      [Object]$PnPCreds
    )
  
    try {
      $cnSite = Connect-PnPOnline -Url $siteUrl @PnPCreds -ReturnConnection
      Invoke-PnPSiteTemplate -Path "$templatePath" -Connection $cnSite -Verbose
      Write-Host "SiteTemplate `'$($template.templateName)`' applied for site $($cnSite.Url)" -ForegroundColor Green
    }
    catch {
      $exception = Get-PnPException
      throw "Error applying `'$($template.templateName)`' for site $($cnSite.Url): $($exception.Message)"
    }
}

# get templates to deploy
$templates = Get-Content -Path "./spo/templates.json" | ConvertFrom-Json
$templates = $templates.templates | Sort-Object SortOrder
  
foreach ($template in $templates) {
  $templatePath = "$($template.relativePath)/$($template.templateName)"
  Invoke-SiteTemplate -siteUrl "https://$($global:M365_TENANTNAME).sharepoint.com/sites/$($template.target)" -templatePath $templatePath -PnPCreds $global:PnPCreds
}