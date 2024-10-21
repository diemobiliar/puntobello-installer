<#
.SYNOPSIS
    SPFx deploy script

.DESCRIPTION
    The script imports a PowerShell module called login.psm1 and then searches for SharePoint package files (.sppkg) in the current directory and its subdirectories. 
    For each package file found, the script attempts to add the package to the SharePoint app catalog using the Add-PnPApp cmdlet. 
    If the package is successfully added, the script publishes the package using the Publish-PnPApp cmdlet.

.EXAMPLE
    Start the script with Deploy-SPWP.ps1
#>

if (Test-Path -Path '/.dockerenv') {
    $importPath = '/usr/local/bin'
} else {
    $importPath = './.devcontainer/scripts'
}
Import-Module "$($importPath)/config.psm1" -Force -DisableNameChecking
Import-Module "$($importPath)/login.psm1" -Force -DisableNameChecking
Import-Module "$($importPath)/functions.psm1" -Force -DisableNameChecking

Write-Information "`e[34mDeploying Apps to Tenant App Catalog`e[0m"
foreach ($solution in (Get-Content ./spo/solutions.json | ConvertFrom-Json).sites.solutions.Name | Sort-Object -Unique) {
    try {
        $appPath = "$($PWD.Path)/$($solution)/sharepoint/solution/$($solution).sppkg"
        $app = Add-PnPApp -Path $appPath -Overwrite -Connection $global:cnAppCatalog
        Write-Information "$($app.Title) added."
        Publish-PnPApp -Identity $app.Id -Connection $global:cnAppCatalog
        Write-Information "$($app.Title) published."
   
    } catch {
        Write-Error "Error occurred while processing $($solution): $($_.Exception.Message)" 
    }
}
foreach ($site in (Get-Content ./spo/solutions.json | ConvertFrom-Json).sites) {
    Write-Information "`e[34mDeploying Apps to site $($site.Url)`e[0m"
    $cnSite = Connect-PnPOnline -Url "https://$($global:M365_TENANTNAME).sharepoint.com/sites/$($site.Url)" @PnPCreds -ReturnConnection -WarningAction Ignore
    $web = Get-PnPWeb -Includes AppTiles -Connection $cnSite
    foreach ($solution in $site.solutions) {
        $app = Get-PnPApp -Identity $solution.Name -Connection $cnAppCatalog 
        if ($null -eq ($web.AppTiles | Where-Object { $_.Title -eq $app.Title })) {
            Install-PnPApp -Identity $app.Id -Connection $cnSite
            Write-Information "$($app.Title) installed."
        } else {
            Update-PnPApp -Identity $app.Id -Connection $cnSite
            Write-Information "$($app.Title) updated."
        }
        if ($null -ne $solution.customAction) {
            Add-PnPCustomAction -Name $solution.customAction.title -Title $solution.customAction.title -Location $solution.customAction.location -ClientSideComponentId $solution.customAction.clientSideComponentId -ClientSideComponentProperties $solution.customAction.clientSideComponentProperties -Connection $cnSite
            Write-Information "Custom Action $($solution.customAction.title) added."
        }
        if ($solution.applicationCustomizer -eq $true){
            Add-ApplicationCustomizer -solution $solution -urlStub $($site.Url)
        }
    }
}
Write-Information "`e[32mApp deployment completed`e[0m"