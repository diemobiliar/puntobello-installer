<#
.SYNOPSIS
    Logic module to showcase different auth variants

.DESCRIPTION
    This PowerShell module provides several variants for authenticating with Microsoft 365 using an Entra ID App Registration. 
    The variants include using an app secret, a pfx file, a certificate that is base64 encoded, or getting the parameters from a KeyVault. 
    The module sets global variables for the app ID, app secret, and tenant name, and creates a PnP connection to the SharePoint admin site and the app catalog. 
    The module can be used to automate the authentication process for Microsoft 365 and SharePoint environments.

.PARAMETER appId
    The ID of the Entra ID App Registration.

.PARAMETER appSecret
    The secret key for the Entra ID App Registration, used for legacy authentication.

.PARAMETER M365_TENANTNAME
    The name of the Microsoft 365 tenant.

.PARAMETER appName
    The name of the Entra ID App Registration.

.PARAMETER certPwd
    A secure string containing the password for the pfx file or base64-encoded certificate.

.PARAMETER certPath
    The path to the pfx file for the Entra ID App Registration, used for certificate-based authentication.

.PARAMETER keyVaultName
    The name of the Azure Key Vault containing the Entra ID App Registration parameters, used for KeyVault-based authentication.

.PARAMETER keyVaultSubscriptionId
    The subscription ID for the Azure Key Vault, used for KeyVault-based authentication.

.PARAMETER secretNameAppId
    The name of the secret in the Azure Key Vault containing the client ID for the Entra ID App Registration, used for KeyVault-based authentication.

.PARAMETER secretNameTenantName
    The name of the secret in the Azure Key Vault containing the Microsoft 365 tenant name, used for KeyVault-based authentication.

.PARAMETER secretNameCertificate
    The name of the secret in the Azure Key Vault containing the base64-encoded certificate for the Entra ID App Registration, used for KeyVault-based authentication.

.EXAMPLE
    There are different variants, please choose one and delete the others or use the selector.
    Every variants has its own variables to set.
#>

switch ($global:loginSelector) {

    ################################################################
    ## Variant 1: Use Entra ID App Reg with App Secret (Legacy Auth)
    ################################################################

    1 {
        $global:PnPCreds = @{
            ClientId     = $global:appId
            ClientSecret = $global:appSecret
        }
    }

    ################################################################
    ## Variant 2: Use Entra ID App Reg with pfx File
    ################################################################
    2 {
        # Create a new self signed cert to use with your app
        $cert = New-SelfSignedCertificate -DnsName $global:appName -CertStoreLocation "cert:\CurrentUser\My"
        Export-PfxCertificate -Cert $cert -FilePath $global:certPath -Password $global:certPwd
        Export-Certificate -Cert $cert -FilePath $global:certPath.Replace(".pfx", ".cer")

        # Upload cer file to certificate section in entra id app reg
        # Use pfx file to auth
        
        $global:PnPCreds = @{
            ClientId            = $global:appId
            CertificatePath     = $global:certPath
            CertificatePassword = $global:certPwd
            Tenant              = "$($global:M365_TENANTNAME).onmicrosoft.com"
        }
    }

    ################################################################
    ## Variant 3: Use Entra ID App Reg with Cert base64 encoded
    ################################################################

    3 {
        $fileContentBytes = Get-Content $global:certPath -AsByteStream
        $certB64 = [System.Convert]::ToBase64String($fileContentBytes)

        $global:PnPCreds = @{
            ClientId                 = $global:appId
            CertificateBase64Encoded = $certB64
            CertificatePassword      = $global:certPwd
            Tenant                   = "$($global:M365_TENANTNAME).onmicrosoft.com"
        }
    }

    ################################################################
    ## Variant 4: Use Entra ID App Reg, get Parameters from KeyVault
    ################################################################

    4 {
        # Interactive Login to Azure with your Account
        try {
            Connect-AzAccount -UseDeviceAuthentication -SubscriptionId $global:keyVaultSubscriptionId
            $CLIMICROSOFT365_AADAPPID = Get-AzKeyVaultSecret -VaultName $global:keyVaultName -Name $global:secretNameAppId -AsPlainText 
            $global:M365_TENANTNAME = Get-AzKeyVaultSecret -VaultName $global:keyVaultName -Name $global:secretNameTenantName -AsPlainText
            $CLIMICROSOFT365_CERT = Get-AzKeyVaultSecret -VaultName $global:keyVaultName -Name $global:secretNameCertificate -AsPlainText
        }
        catch {
            Write-Host "Error occurred while getting credentials from KeyVault: $($_.Exception.Message)" -ForegroundColor Red
        }

        $global:PnPCreds = @{
            ClientId                 = $CLIMICROSOFT365_AADAPPID
            CertificateBase64Encoded = $CLIMICROSOFT365_CERT
            Tenant                   = "$($global:M365_TENANTNAME).onmicrosoft.com"
        }
    }

    ################################################################
    ## Variant 5: Use OAuth2 access token
    ################################################################

    5 {
        $tokenEndpoint = "https://login.microsoftonline.com/$($global:M365_TENANTNAME).sharepoint.com/oauth2/token"
        $body = @{
            grant_type    = "client_credentials"
            client_id     = $global:appId
            client_secret = $global:appSecret
            resource      = "https://$($global:M365_TENANT_NAME).sharepoint.com/"
        }
        $response = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $body
        $global:PnPCreds = @{
            AccessToken = $($response.access_token)
        }
    }

    ################################################################
    ## Variant 6: Use Username and Password
    ################################################################

    6 {
        $creds = New-Object System.Management.Automation.PSCredential ($global:adminUser, $global:password)
        $global:PnPCreds = @{
            Credentials = $creds
        }
    }
}

################################################################
## Use for all variants
#################################################################

try {
    $global:cnAdmin = Connect-PnPOnline -Url "https://$($global:M365_TENANTNAME)-admin.sharepoint.com" @global:PnPCreds -ReturnConnection
    $global:cnAppCatalog = Connect-PnPOnline -Url (Get-PnPTenantAppCatalogUrl -Connection $global:cnAdmin) @global:PnPCreds -ReturnConnection
}
catch {
    Write-Host "Error occurred while authenticating: $($_.Exception.Message)" -ForegroundColor Red
}