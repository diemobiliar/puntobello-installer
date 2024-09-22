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
    .\Deploy-SitesAndLists
    Ensures the specified site collections exist and applies templates from the solutions.json file.
#>

# Import required modules
if (Test-Path -Path '/.dockerenv') {
    $importPath = '/usr/local/bin'
} else {
    $importPath = './.devcontainer/scripts'
}
Import-Module "$($importPath)/config.psm1" -Force -DisableNameChecking
Import-Module "$($importPath)/login.psm1" -Force -DisableNameChecking
Import-Module "$($importPath)/functions.psm1" -Force -DisableNameChecking

# Ensure target site collections configured in exist, create if required.
if (Test-Path './spo/solutions.json') {
    Write-Information "`e[34mCreate termSets`e[0m"
    foreach ($termSet in ((Get-Content ./spo/solutions.json | ConvertFrom-Json).termStore.termSets)) {
        Add-TermSet -termSetPath $termSet
    }
    Write-Information "`e[34mDeploy sites`e[0m"
    foreach ($site in  (Get-Content ./spo/solutions.json | ConvertFrom-Json).sites) {
        Assert-SiteCollection -siteDefinition $site
        Write-Information "Apply site templates for $($site.Url)"
        foreach ($template in $site.templates | Sort-Object sortOrder) {
            if ($template.templateName -eq 'SitePages.xml') {
                Add-SitePagesFields -template $template -urlStub $site.Url
            } else {
                Invoke-SiteTemplate -template $template -urlStub $site.Url
            }
        }

    }
} else {
    Write-Error 'solutions.json not found'
    exit 1
}

