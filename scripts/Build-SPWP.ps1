$wps = Get-ChildItem -Path . -Filter "package.json" -Recurse -Depth 2 -File
foreach($wp in $wps){
    Write-Host "Working on $($wp.Directory.Name)" -Foregroundcolor Green
    cd $($wp.Directory.FullName)
    npm install && npm run pbship
    cd ..
}