<#
.SYNOPSIS
    Deploys SharePoint site collections and applies site templates as specified in the configuration.

.DESCRIPTION
    This script ensures that the target SharePoint site collections exist and creates them if necessary.
    It then processes a JSON file containing site templates and applies these templates to the specified sites.

.IMPORTS
    - config.psm1: Contains configuration settings.
    - login.psm1: Handles authentication and login to SharePoint.
    - functions.psm1: Contains utility functions such as Assert-SiteCollection and Invoke-SiteTemplate.

.NOTES
    This script requires the PnP PowerShell module and appropriate permissions to create site collections and apply templates.

.EXAMPLE
    .\Deploy-SitesAndLists.ps1
    Ensures the specified site collections exist and applies templates from the templates.json file.
#>

# Import required modules
if (Test-Path /proc/1/cgroup) {
    $importPath = "/usr/local/bin"
} else {
    $importPath = "./.devcontainer/scripts"
}
Import-Module "$($importPath)/config.psm1" -Force
Import-Module "$($importPath)/login.psm1" -Force
Import-Module "$($importPath)/functions.psm1" -Force

# Ensure target site collections configured in config.psm1 exist, create if required.

if (Test-Path "./spo/solutions.json"){
    foreach($site in  (Get-Content ./spo/solutions.json | ConvertFrom-Json).solutions.targets | Sort-Object -Unique) {
        Assert-SiteCollection -siteName $site -SiteTitle $site
    }
}

# Process template.json if present
if (Test-Path "./spo/templates.json") {
    foreach($template in (Get-Content ./spo/templates.json | ConvertFrom-Json).templates | Sort-Object sortOrder) {
        Invoke-SiteTemplate -template $template
    }
}