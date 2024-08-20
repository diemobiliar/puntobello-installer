# ################################################################
# ## Variant 1: Use Entra ID App Reg with App Secret (Legacy Auth)
# ################################################################

# $appId = "503bff26-ed45-4e44-b885-94353d6981ce"
# $appSecret = Read-Host -Prompt $Prompt
# $global:M365_TENANTNAME = "fhu365"

# $global:PnPCreds = @{
#     ClientId        = $appId
#     ClientSecret    = $appSecret
# }

# ################################################################
# ## Variant 2: Use Entra ID App Reg with pfx File
# ################################################################

# $appId = "503bff26-ed45-4e44-b885-94353d6981ce"
# $appName = "yourappname"
# $global:M365_TENANTNAME = "fhu365"
# $certPwd = ConvertTo-SecureString -String "asecurestring" -Force -AsPlainText
# $certPath = "C:\yourpath\$appName.pfx"

# # Create a new self signed cert to use with your app
# $cert = New-SelfSignedCertificate -DnsName $appName -CertStoreLocation "cert:\CurrentUser\My"
# Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $certPwd
# Export-Certificate -Cert $cert -FilePath $certPath.Replace(".pfx",".cer")

# # Upload cer file to certificate section in entra id app reg
# # Use pfx file to auth

# $global:PnPCreds = @{
#     ClientId            = $appId
#     CertificatePath     = $certPath
#     CertificatePassword = $certPwd
#     Tenant              = "$global:M365_TENANTNAME.onmicrosoft.com"
# }

# ################################################################
# ## Variant 3: Use Entra ID App Reg with Cert base64 encoded
# ################################################################

# $appId = "503bff26-ed45-4e44-b885-94353d6981ce"
# $global:M365_TENANTNAME = "fhu365"
# $certPwd = ConvertTo-SecureString -String "asecurestring" -Force -AsPlainText
# $certPath = "C:\yourpath\$appName.pfx"

# $fileContentBytes = Get-Content $certPath -AsByteStream
# $certB64 = [System.Convert]::ToBase64String($fileContentBytes)

# $global:PnPCreds = @{
#     ClientId                    = $appId
#     CertificateBase64Encoded    = $certB64
#     CertificatePassword         = $certPwd
#     Tenant                      = "$global:M365_TENANTNAME.onmicrosoft.com"
# }

################################################################
## Variant 4: Use Entra ID App Reg, get Parameters from KeyVault
################################################################

$keyVaultName = "mobi-redn-d3-kv"
$keyVaultSubscriptionId = "bf408115-a9b5-49bf-a497-24112465a319"
$secretNameAppId = "CLIMICROSOFT365-AADAPPID-D3"
$secretNameTenantName = "M365-TENANTNAME-D3"
$secretNameCertificate = "m365-spo-d3-sp"

# Interactive Login to Azure with your Account
Connect-AzAccount -UseDeviceAuthentication -SubscriptionId $keyVaultSubscriptionId
$CLIMICROSOFT365_AADAPPID = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretNameAppId -AsPlainText 
$global:M365_TENANTNAME =  Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretNameTenantName -AsPlainText
$CLIMICROSOFT365_CERT = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretNameCertificate -AsPlainText

$global:PnPCreds = @{
    ClientId                    = $CLIMICROSOFT365_AADAPPID
    CertificateBase64Encoded    = $CLIMICROSOFT365_CERT
    Tenant                      = "$global:M365_TENANTNAME.onmicrosoft.com"
}

################################################################
## Use for all variants
#################################################################

$global:adminUser = "master@$($global:M365_TENANTNAME).onmicrosoft.com"
$global:cnAdmin = Connect-PnPOnline -Url "https://$($global:M365_TENANTNAME)-admin.sharepoint.com" @global:PnPCreds -ReturnConnection
$global:cnAppCatalog = Connect-PnPOnline -Url (Get-PnPTenantAppCatalogUrl -Connection $global:cnAdmin) @global:PnPCreds -ReturnConnection