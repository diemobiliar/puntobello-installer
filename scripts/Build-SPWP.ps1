<#
.SYNOPSIS
    SPFx build script

.DESCRIPTION
    This PowerShell script automates the build of multiple SPFx solutions. 
    It searches for all package.json files in the current directory and its subdirectories, installs the necessary dependencies, and runs the "pbship" command to deploy the packages. 

.EXAMPLE
    Start the script with Build-SPWP.ps1
#>

if (Test-Path -Path '/.dockerenv') {
    $importPath = '/usr/local/bin'
} else {
    $importPath = './.devcontainer/scripts'
}
Import-Module "$($importPath)/config.psm1" -Force -DisableNameChecking

if ([string]::IsNullOrEmpty($env:NODE_ENV)) {
    Write-Error '$env:NODE_ENV needs to be set'
    exit 1
}

foreach ($solution in (Get-Content ./spo/solutions.json | ConvertFrom-Json).sites.solutions.Name | Sort-Object -Unique) {
    Write-Information "`e[34mBuilding  $($solution)`e[0m"
    Set-Location "$($PWD.Path)/$($solution)"
    try {
        npm install && npm run pbship:$($env:NODE_ENV)
    } catch {
        Write-Error "Error occurred while running npm commands: $_" 
    }
    Set-Location ..
}