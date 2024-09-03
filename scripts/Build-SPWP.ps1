<#
.SYNOPSIS
    SPFx build script

.DESCRIPTION
    This PowerShell script automates the build of multiple SPFx solutions. 
    It searches for all package.json files in the current directory and its subdirectories, installs the necessary dependencies, and runs the "pbship" command to deploy the packages. 

.EXAMPLE
    Start the script with Build-SPWP.ps1
#>

if (Test-Path /proc/1/cgroup) {
    $importPath = "/usr/local/bin"
} else {
    $importPath = "./.devcontainer/scripts"
}
Import-Module "$($importPath)/config.psm1" -Force

if ([string]::IsNullOrEmpty($env:NODE_ENV)) {
    Write-Error '$env:NODE_ENV needs to be set'
    exit 1
}

foreach($solution in (Get-Content ./spo/solutions.json | ConvertFrom-Json).solutions){
    Write-Host "Working on $($solution.solutionName)" -Foregroundcolor Green
    cd "$($PWD.Path)/$($solution.solutionName)"
    try {
        npm install && npm run pbship:$($env:NODE_ENV)
    }
    catch {
        Write-Host "Error occurred while running npm commands: $($_.Exception.Message)" -ForegroundColor Red
    }
    cd ..
}