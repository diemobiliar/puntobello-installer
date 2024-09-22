$global:InformationPreference = 'Continue'
$global:VerbosePreference = 'SilentlyContinue'
$env:NODE_ENV = "dev"
$global:M365_TENANTNAME = "puntobello"
$global:adminUser = "admin@$($global:M365_TENANTNAME).onmicrosoft.com"

# Login parameters
$global:loginSelector = 6
switch ($global:loginSelector) {

    ################################################################
    ## Variant 1: Use Entra ID App Reg with App Secret (Legacy Auth)
    ################################################################

    1 {
        $global:appId = "1676d752-c83b-4f61-adb5-1657348780d3"
        $global:appSecret = "secretasstring"
    }

    ################################################################
    ## Variant 2: Use Entra ID App Reg with pfx File
    ################################################################
    2 {
        $global:appId = "1676d752-c83b-4f61-adb5-1657348780d3"
        $global:appName = "yourappname"
        $global:certPwd = ConvertTo-SecureString -String "secretasstring" -Force -AsPlainText
        $global:certPath = "C:\yourpath\$($global:appName).pfx"
    }

    ################################################################
    ## Variant 3: Use Entra ID App Reg with Cert base64 encoded
    ################################################################

    3 {
        $global:appId = "1676d752-c83b-4f61-adb5-1657348780d3"
        $global:certPwd = ConvertTo-SecureString -String "secretasstring" -Force -AsPlainText
        $global:certPath = "C:\yourpath\$($global:appName).pfx"
    }

    ################################################################
    ## Variant 4: Use Entra ID App Reg, get Parameters from KeyVault
    ################################################################

    4 {
        $global:keyVaultName = "puntobello-kv"
        $global:keyVaultSubscriptionId = "31cc0dc4-885c-4742-913f-9324393623b6"
        $global:secretNameAppId = "CLIMICROSOFT365-ENTRAAPPID"
        $global:secretNameTenantName = "M365-TENANTNAME"
        $global:secretNameCertificate = "m365-spo-sp"
    }

    ################################################################
    ## Variant 5: Use OAuth2 access token
    ################################################################

    5 {
        $global:appId = "1676d752-c83b-4f61-adb5-1657348780d3"
        $global:appSecret = "secretasstring"
    }

    ################################################################
    ## Variant 6: Use Username and Password
    ################################################################

    6 {
        $global:username = $global:adminUser
        $global:password = ConvertTo-SecureString -String "passwordasstring" -Force -AsPlainText
    }
}