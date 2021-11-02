<#
Disclaimer
The sample scripts are not supported under any Microsoft standard support program or service.
The sample scripts are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without limitation, 
any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample 
scripts and documentation remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery 
of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss 
of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, even if 
Microsoft has been advised of the possibility of such damages.
#>


function GetSSLCertificateDaysToExpiry {
    param (
        [string]$url
    )

    # Disable the SSL certificate validation check
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    # Execute HTTP get request to fecth SSL certificate
    $request = [Net.HttpWebRequest]::Create($url)
    $request.Timeout = 10000
    $request.AllowAutoRedirect = $false
    try {
        $request.GetResponse() | Out-Null
    } catch {
        Write-Error "$($_.Exception.Message)"
    }

    # If for some reason unable to retrieve SSL certificate return null
    if ( $request.ServicePoint.Certificate -eq $null ) {
        return $null
    }
    # Else parse SSL certificate and return days to expiry  
    else {
        $certExpiresOnString = $request.ServicePoint.Certificate.GetExpirationDateString()
        [datetime]$expiration = [System.DateTime]::Parse($request.ServicePoint.Certificate.GetExpirationDateString())
        [int]$certExpiresIn = ($expiration - $(get-date)).Days
        return $certExpiresIn
    }
}

Function _SendToLogAnalytics {
    Param(
        [string]$customerId,
        [string]$sharedKey,
        [string]$logs,
        [string]$logType,
        [string]$timeStampField
    )
        # Generate the body for the Invoke-WebRequest
        $body = ([System.Text.Encoding]::UTF8.GetBytes($logs))
        $method = "POST"
        $contentType = "application/json"
        $resource = "/api/logs"
        $rfc1123date = [DateTime]::UtcNow.ToString("r")
        $contentLength = $body.Length

        #Create the encoded hash to be used in the authorization signature
        $xHeaders = "x-ms-date:" + $rfc1123date
        $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
        $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
        $keyBytes = [Convert]::FromBase64String($sharedKey)
        $sha256 = New-Object System.Security.Cryptography.HMACSHA256
        $sha256.Key = $keyBytes
        $calculatedHash = $sha256.ComputeHash($bytesToHash)
        $encodedHash = [Convert]::ToBase64String($calculatedHash)
        $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash

        # Create the uri for the data insertion endpoint for the Log Analytics workspace
        $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

        # Create the headers to be used in the Invoke-WebRequest
        $headers = @{
            "Authorization" = $authorization;
            "Log-Type" = $logType;
            "x-ms-date" = $rfc1123date;
            "time-generated-field" = $timeStampField;
        }
    
        # Try to send the logs to the Log Analytics workspace
        Try {
            $response = Invoke-WebRequest `
            -Uri $uri `
            -Method $method `
            -ContentType $contentType `
            -Headers $headers `
            -Body $body `
            -UseBasicParsing `
            -ErrorAction stop `
            | Out-Null
        }
        # Catch any exceptions and write them to the output 
        Catch {
            Write-Error "$($_.Exception)"
            throw "$($_.Exception)" 
        }

        # Return the status code of the web request response
        return $response
}

# Declare variables from Automation Account variables 
$urlList = (Get-AutomationVariable -Name 'urlList').Split(",")
$logAnalyticsWorkspaceID = Get-AutomationVariable -Name 'logAnalyticsWorkspaceID'
$logAnalyticsPrimaryKey = Get-AutomationVariable -Name 'logAnalyticsPrimaryKey'

Write-Output "Checking SSL certificates for the following URLs:"
foreach ($url in $urlList) {
    Write-Output "- $url"
}

foreach ($url in $urlList) {
    Write-Output "`n-----------------------------------------------"
    Write-Output "Checking SSL certificate for $url..."

    $timeStamp = Get-Date -format o
    # Get SSL certificate's days to expiry
    $certExpiresIn = GetSSLCertificateDaysToExpiry($url)

    # If not null send log to Log Analytics Workspace
    if ($certExpiresIn -ne $null) {
        Write-Output "SSL certificate at $url has $certExpiresIn days left until expiration."

        $logEntry = "{`"TimeStamp`": `"$timeStamp`", `"url`": `"$url`", `"certExpiresIn`": $certExpiresIn}"
        Write-Output "Sending following log entry to Log Analytics Workspace:`n$logEntry"
        _SendToLogAnalytics -CustomerId $logAnalyticsWorkspaceID `
                            -SharedKey $logAnalyticsPrimaryKey `
                            -Logs $logEntry `
                            -LogType "CertificateExpiration" `
                            -TimeStampField "TimeStamp"
        Write-Output "Log entry sent to Log Analytics Workspace."
    }
    # If null don't send anything to Log Analytics Workspace
    else {
        Write-Error "Will not write to Log Analytics Workspace since an SSL certificate could not be retrieved."
    }
}
