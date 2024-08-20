Import-Module /usr/local/bin/login.psm1 -Force

$wps = Get-ChildItem -Path . -Filter "*.sppkg" -Recurse -Depth 3 -File

foreach($wp in $wps){
    $app = Add-PnPApp -Path $wp.FullName -Overwrite -Connection $global:cnAppCatalog
    Write-Host "$($app.Title) added."
    Publish-PnPApp -Identity $app.Id -Connection $global:cnAppCatalog
    Write-Host "$($app.Title) published."
    # $cnSite = Connect-PnPOnline -Url "https://fhu365.sharepoint.com/sites/rednet" @PnPCreds -ReturnConnection
    # $web = Get-PnPWeb -Includes AppTiles -Connection $cnSite
    # if($null -eq ($web.AppTiles | Where-Object {$_.Title -eq $app.Title})){
    #     Install-PnPApp -Identity $app.Id -Connection $cnSite
    #     Write-Host "$($app.Title) installed."
    # }
    # else {
    #     Update-PnPApp -Identity $app.Id -Connection $cnSite
    #     Write-Host "$($app.Title) updated."
    # }
}