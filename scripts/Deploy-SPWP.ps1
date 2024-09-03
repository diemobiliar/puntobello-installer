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

if (Test-Path /proc/1/cgroup) {
    $importPath = "/usr/local/bin"
} else {
    $importPath = "./.devcontainer/scripts"
}
Import-Module "$($importPath)/config.psm1" -Force
Import-Module "$($importPath)/login.psm1" -Force

foreach($solution in (Get-Content ./spo/solutions.json | ConvertFrom-Json).solutions){
    try {
        $appPath = "$($PWD.Path)/$($solution.solutionName)/sharepoint/solution/$($solution.solutionName).sppkg"
        $app = Add-PnPApp -Path $appPath -Overwrite -Connection $global:cnAppCatalog
        Write-Host "$($app.Title) added."
        Publish-PnPApp -Identity $app.Id -Connection $global:cnAppCatalog
        Write-Host "$($app.Title) published."
        foreach($site in $solution.targets){
            $cnSite = Connect-PnPOnline -Url "https://$($global:M365_TENANTNAME).sharepoint.com/sites/$($site)" @PnPCreds -ReturnConnection
            $web = Get-PnPWeb -Includes AppTiles -Connection $cnSite
            if($null -eq ($web.AppTiles | Where-Object {$_.Title -eq $app.Title})){
                Install-PnPApp -Identity $app.Id -Connection $cnSite
                Write-Host "$($app.Title) installed."
            }
            else {
                Update-PnPApp -Identity $app.Id -Connection $cnSite
                Write-Host "$($app.Title) updated."
            }
        }
    }
    catch {
        Write-Host "Error occurred while processing $($wp.FullName): $($_.Exception.Message)" -ForegroundColor Red
    }
}