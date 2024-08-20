$runCount = 0
$maxRuns = 10
$reRunRequired = $true

# ReadSecurity
# 1=read all items
# 2=read items created by user

# WriteSecurity
# 1=Create and edit All items
# 2=Create items and edit items that were created by the user
# 4=None

# Get configuration information for all lists
$ListPermissions = (Get-Content -path ./spo/assets/lists/listPermissions.json -Encoding UTF8).Replace("@@tenant@@", $global:M365_TENANTNAME) | ConvertFrom-Json

#debug
# $ListPermissions.Sites = $ListPermissions.Sites[0]

# iterate through all config items
while ($reRunRequired -and ($runCount -lt $maxRuns)) {
    $reRunRequired = $false
    $runCount++
    Write-Host "Starting run #$($runCount)" -ForegroundColor DarkMagenta
    $ListPermissions | ForEach-Object {
        $ListConfig = $_
        Write-Host "Configure ListPermissions `'$($ListConfig.Permission)`'"
        $ListConfig.Sites  | ForEach-Object {
            $Site = $_
            Write-Host "Working on $($Site.Url)"
            $cnSite = Connect-PnPOnline -Url $Site.Url @global:pnpCreds -ReturnConnection
            $Site.ListUrls | ForEach-Object {
                $ListUrl = $_
                try {
                    $List = Get-PnPList $ListUrl -Includes ReadSecurity, WriteSecurity, HasUniqueRoleAssignments, RoleAssignments -Connection $cnSite
                    if ($ListConfig.BreakRoleInheritance) {
                        if (!($List.HasUniqueRoleAssignments)) {
                            # break Permission Inheritance if required
                            Write-Host "Breaking Role Inheritance for $ListUrl"
                            Set-PnPList -Identity $List -BreakRoleInheritance -CopyRoleAssignments -Connection $cnSite
                        }
                        $visitorGroup = Get-PnPGroup -AssociatedVisitorGroup -Connection $cnSite
                        # Add required permissions
                        $currentPermission = Get-PnPListPermissions -Identity $List -PrincipalId $visitorGroup.Id -Connection $cnSite -ErrorAction SilentlyContinue
                        if ($currentPermission.Name -ne $($ListConfig.Permission)) {
                            Write-Host "Adding `'$($ListConfig.Permission)`' for $($visitorGroup.Title) on List $ListUrl"
                            Set-PnPListPermission -Identity $list -Group $visitorGroup -AddRole $ListConfig.Permission -Connection $cnSite
                        }
                        $currentPermission = Get-PnPListPermissions -Identity $List -PrincipalId  $visitorGroup.Id -Connection $cnSite -ErrorAction SilentlyContinue
                        if ($currentPermission.count -ne 1) {
                            # If there are multiple assignments, get rid of them...
                            $currentPermission | ForEach-Object {
                                Write-Host "Removing `'$($_.Name)`' for $($visitorGroup.Title) on List $ListUrl"
                                Set-PnPListPermission -Identity $List -Group $visitorGroup -RemoveRole $_.Name -Connection $cnSite
                            }
                            Write-Host "Re-Adding `'$($ListConfig.Permission)`' for $($visitorGroup.Title) on List $ListUrl"
                            Set-PnPListPermission -Identity $list -Group $visitorGroup -AddRole $ListConfig.Permission -Connection $cnSite
                            $reRunRequired = $true
                        }
                        # once the group permissions are configured correctly, proceed
                        if ($reRunRequired -eq $false) {
                            if ($list.ReadSecurity -ne $ListConfig.Security.Read -or $List.WriteSecurity -ne $ListConfig.Security.Write)  {
                                $List.ReadSecurity = $ListConfig.Security.Read
                                $List.WriteSecurity = $ListConfig.Security.Write
                                $List.Update()
                                Invoke-PnPQuery -Connection $cnSite
                            }
                        }
                    }
                    else {
                        Write-Host "Restoring Role Inheritance for $ListUrl"
                        Set-PnPList -Identity $List -ResetRoleInheritance -Connection $cnSite
                    }
                }
                catch {
                    
                }
            }
        }
    }
}


if ($runCount -eq $maxRuns) {
    throw "Script did not complete within $($maxRuns) iterations" 
}
else {
    Write-Host "Script completed successfully with $($runCount) iterations" -ForegroundColor green
}