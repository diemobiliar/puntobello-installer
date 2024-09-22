<#
.SYNOPSIS
    Ensures that a SharePoint site collection exists, and creates it if it does not.

.DESCRIPTION
    The Assert-SiteCollection function checks if a SharePoint site collection exists at the specified URL.
    If the site collection does not exist, it creates a new Communication Site with the specified title.

.PARAMETER SiteName
    The name of the site collection to check or create.

.PARAMETER SiteTitle
    The title of the site collection to create if it does not exist.

.EXAMPLE
    Assert-SiteCollection -SiteName "exampleSite" -SiteTitle "Example Site"
    Ensures that the site collection "exampleSite" exists, and creates it with the title "Example Site" if it does not.

.NOTES
    This function requires the PnP PowerShell module and appropriate permissions to create site collections.
#>
function Assert-SiteCollection {
    param (
        [Parameter()]
        [psobject]$siteDefinition
    )

    $Url = "https://$($global:M365_TENANTNAME).sharepoint.com/sites/$($siteDefinition.Url)"

    if($null -eq (Get-PnPTenantSite -Url $Url -Connection $global:cnAdmin -ErrorAction SilentlyContinue)){
        try {
            Write-Information "Creating Site $($Url)"
            New-PnPSite -Type "CommunicationSite" -Title $siteDefinition.Title -Url $Url -Lcid $siteDefinition.LCID -Owner $global:adminUser -Connection $global:cnAdmin    
            Write-Information "`e[90mWait 30 seconds after site creation`e[0m"
            Start-Sleep 30
        }
        catch {
            throw "Site Creation for $($Url) failed: $_"
        }
        
    } else {
        Write-Verbose "Site $($Url) already exists"
    }
}
Export-ModuleMember -Function Assert-SiteCollection

<#
.SYNOPSIS
    Applies a PnP site template to a specified SharePoint site.

.DESCRIPTION
    The Invoke-SiteTemplate function connects to a specified SharePoint site and applies a PnP site template from a given path.

.PARAMETER siteUrl
    The URL of the SharePoint site to which the template will be applied.

.PARAMETER templatePath
    The path to the PnP site template file to apply.

.EXAMPLE
    Invoke-SiteTemplate -siteUrl "https://example.sharepoint.com/sites/exampleSite" -templatePath "C:\Templates\exampleTemplate.xml"
    Connects to the site "exampleSite" and applies the template located at "C:\Templates\exampleTemplate.xml".

.NOTES
    This function requires the PnP PowerShell module and appropriate permissions to apply site templates.
#>
function Invoke-SiteTemplate {
    param (
        [Parameter()]
        [PSObject]$template,
        [String]$urlStub
    )
  
    try {   
        $siteUrl = "https://$($global:M365_TENANTNAME).sharepoint.com/sites/$($urlStub)"
        $cnSite = Connect-PnPOnline -Url $siteUrl @global:PnPCreds -ReturnConnection -WarningAction Ignore
        $templatePath = "$($template.relativePath)/$($template.templateName)"
        Invoke-PnPSiteTemplate -Path $templatePath -Connection $cnSite -Verbose
        Write-Information "`e[32mSiteTemplate `'$($template.templateName)`' applied for site $($cnSite.Url)`e[0m" 

    }
    catch {
      throw "Error applying `'$($template.templateName)`' for site $($cnSite.Url): $_"
    }
}
Export-ModuleMember -Function Invoke-SiteTemplate

<#
.SYNOPSIS
    Ensures and creates a Termgroup and Termset

.DESCRIPTION
    This function verify if a Termgrouo and Termset exists in Term store. If not it will be created.

.PARAMETER termGroupPath
    The full path of the Termset.

.EXAMPLE
    Add-TermSet -termSetPath "Puntobello|Channels"

.NOTES
    This function requires the PnP PowerShell module and appropriate permissions to create a term set and group.
#>
function Add-TermSet {
    param (
        [Parameter()]
        [String]$termSetPath
    )
    try {
            # Define the term group and term set names
    $termGroupName = $termSetPath.Split("|")[0]
    $termSetName = $termSetPath.Split("|")[1]

    # Check if the term group already exists
    $termGroup = Get-PnPTermGroup -Identity $termGroupName -Connection $global:cnAdmin -ErrorAction SilentlyContinue

    # If the term group doesn't exist, create it
    if (!$termGroup) {
        Write-Information "Add term group $termGroupName"
        $termGroup = New-PnPTermGroup -Name $termGroupName -Connection $global:cnAdmin
    }

    # Check if the term set already exists
    $termSet = Get-PnPTermSet -Identity $termSetName -TermGroup $termGroup -Connection $global:cnAdmin -ErrorAction SilentlyContinue

    # If the term set doesn't exist, create it
    if (!$termSet) {
        "Add term set $termSetName"
        $termSet = New-PnPTermSet -Name $termSetName -TermGroup $termGroup -Lcid 1033 -Connection $global:cnAdmin
    }

    # Output the term set ID for reference
    Write-Information "Term Set ID: $($termSet.Id)"
    return $($termSet.Id).Guid
    }
    catch {
        Write-Error "Error creating termset `'$($termSetPath)`': $_"
    }

}
Export-ModuleMember -Function Add-TermSet

<#
.SYNOPSIS
    Add real time news field to site pages list

.DESCRIPTION
    New fields added with site template won't be added to default content type and must be added manually.
    Works on other lists than site pages, so this list is special or it's a bug.

.PARAMETER $template
    Full template to get site urls

.EXAMPLE
    Add-SitePagesFields -template $template

.NOTES
    This function requires the PnP PowerShell module and appropriate permissions to add list fields.
#>
function Add-SitePagesFields {
    param (
        [Parameter()]
        [PSObject]$template,
        [String]$urlStub
    )

    try {   
            $siteUrl = "https://$($global:M365_TENANTNAME).sharepoint.com/sites/$($urlStub)"
            $cnSite = Connect-PnPOnline -Url $siteUrl @global:PnPCreds -ReturnConnection -WarningAction Ignore

            $GUID_pb_Sticky = "e04bb79c-9414-4232-9db5-4d40f4f05f08"
            $GUID_pb_StickyDate = "253d0d96-60a4-4e91-9e17-8f650071c2bd"
            $GUID_pb_Channels = "85fdf7a1-66b5-4075-b2f4-ebc07d91e628"
            $GUID_pb_PublishedFrom = "abcfd13d-2645-4886-8086-cabb7cf18683"
            $GUID_pb_PublishedTo = "1ed63437-a63b-4a67-bc02-c02e3525d1d3"
            
            # Helper function to check if a field exists
            function FieldExists($listName, $internalName, $connection) {
                $field = Get-PnPField -List $listName -Identity $internalName -Connection $connection -ErrorAction SilentlyContinue
                return $null -ne $field
            }

            if (-not (FieldExists -listName "SitePages" -internalName "pb_Sticky" -connection $cnSite)) {
                Add-PnPField -List "SitePages" -DisplayName "Sticky" -InternalName "pb_Sticky" -Id $GUID_pb_Sticky -Group "PuntoBello" -AddToDefaultView  -Type Boolean -Connection $cnSite | Out-Null
                Write-Information "`e[32mAdded field pb_Sticky to SitePages for site $siteUrl`e[0m"                
            }
            
            if (-not (FieldExists -listName "SitePages" -internalName "pb_StickyDate" -connection $cnSite)) {   
                Add-PnPField -List "SitePages" -DisplayName "Sticky date" -InternalName "pb_StickyDate" -Id $GUID_pb_StickyDate -Group "PuntoBello" -AddToDefaultView  -Type DateTime -Connection $cnSite | Out-Null
                Write-Information "`e[32mAdded field pb_StickyDate to SitePages for site $siteUrl`e[0m"
            }

            if (-not (FieldExists -listName "SitePages" -internalName "pb_Channels" -connection $cnSite)) {
                Start-Sleep -Seconds 5
                Add-PnPTaxonomyField -List "SitePages" -DisplayName "Channels" -InternalName "pb_Channels" -TermSetPath "PuntoBello|Channels" -Group "PuntoBello" -AddToDefaultView -Id $GUID_pb_Channels -MultiValue -Connection $cnSite  | Out-Null
                Write-Information "`e[32mAdded field pb_Channels to SitePages for site $siteUrl`e[0m"
            }

            if (-not (FieldExists -listName "SitePages" -internalName "pb_PublishedFrom" -connection $cnSite)) {
                Add-PnPField -List "SitePages" -DisplayName "Published from" -InternalName "pb_PublishedFrom" -Id $GUID_pb_PublishedFrom -Group "PuntoBello" -AddToDefaultView -Type DateTime -Connection $cnSite | Out-Null
                Write-Information "`e[32mAdded field pb_PublishedFrom to SitePages for site $siteUrl`e[0m"
                
            }

            if (-not (FieldExists -listName "SitePages" -internalName "pb_PublishedTo" -connection $cnSite)) {
                Add-PnPField -List "SitePages" -DisplayName "Published to" -InternalName "pb_PublishedTo" -Id $GUID_pb_PublishedTo -Group "PuntoBello" -AddToDefaultView -Type DateTime -Connection $cnSite | Out-Null
                Write-Information "`e[32mAdded field pb_PublishedTo to SitePages for site $siteUrl`e[0m"
            }
    }
    catch {
      throw "Error applying Site Pages Fields for site $($cnSite.Url): $_"
    }
}
Export-ModuleMember -Function Add-SitePagesFields