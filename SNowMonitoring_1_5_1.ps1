."C:\SNow Monitoring\SendIncidentFunction.ps1" # include SendIncidentFunction.ps1 file





# ----------------------------------------- CONFIG ----------------------------------------- 


$computerName = $env:computername | Select-Object # AF computer name
#$computerName = "KCSVPI01"

# Getting the config information from CSV file
# example: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv?view=powershell-7.4
$csvFilePath = "C:\SNow Monitoring\config_table.csv" # CSV config file with [site, af computer name, location name, location id]
$P = Import-Csv -Path $csvFilePath 
$P | Get-Member
$P | Format-Table
$configRow = $P | Where-Object -Property "AF Computer Name" -Like $computerName # CSV row from config table for current AF computer name

$siteName = $configRow.Site
$locationName = $configRow.'Location Name'
$locationID = $configRow.'Location ID'

$logFilePath = "C:\SNow Monitoring\Logs.txt" # Log file for output logs

$passwordFilePath = "C:\ProgramData\OSIsoft\PINotifications\Data\" +$siteName + "\Credentials\credentials.dat" # Password file path
$passwordFileExists = Test-Path $passwordFilePath

$notifFilePath = (Join-Path $env:ProgramData "OSIsoft\PINotifications\Logs") + "\" + "pinotifications-log.txt" # PI Notification Logs file path
$notifFileExists = Test-Path $notifFilePath

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss" # Get the current date and time in a specific format
$logMessage = "--- Powershell Start Time [$timestamp] ---" # Your message to be logged
$logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8 # Use Out-File to write to the log file

# Check if the Mandatory File(s) Exists, If Not Exit
# Log File for output logs is not mandatory, it will be created (assuming the folder exists)
# CSV File for table location ID is not mandatory, it's needed to Send Incident to SNow, but we can still write logs without it
# Password File is not mandatory, we can still write output logs without it, and Send Incident to SNow without it
# PI Notification Logs is MANDATORY for everything
if ($notifFileExists -eq $false) {
    $logMessage =  "File not found at $notifFilePath."
    $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8
    Exit
} 


if ($siteName.Length -eq 0 -or $locationName.Length -eq 0 -or $locationID -eq 0) {
    $logMessage = "Unable to find matching row for AF Server " + $computerName + " in " + $csvFilePath
    $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8  # Use Out-File to write to the log file
} else {
    Write-Host "Config Row:" $configRow
    Write-Host "siteName:" $siteName
    Write-Host "locationName: " $locationName
    Write-Host "locationID: " $locationID
}

# ----------------------------------------- SEARCH ----------------------------------------- 

# Read the file, it's guaranteed to exist at this point
$logs = Get-Content -Path $notifFilePath -Raw # read logs as a raw string

# Define desired search phrases
$desiredPhrases = @("Error:", "Error: SmTP:NoToEmail","401 .*Unauthorized")

$results = @() # search results array
foreach ($phrase in $desiredPhrases) {                 # for each phrase in desired phrases
    Write-Host "DESIRED PHRASE" $phrase
    $found_matches = [regex]::matches($logs, $phrase, [System.Text.RegularExpressions.RegexOptions]::Multiline.value__ -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase.value__)
    Write-Host "Matches?" $found_matches.count
    
    # Save results if matches is at least 1
    if ($found_matches.count -eq 1) {
        $results += ,("Error " + ($results.Count +1) + " found " + $found_matches.count + " time = " + $phrase)
    } elseif ($found_matches.count -gt 1) {
        $results += ,("Error " + ($results.Count +1) + " found " + $found_matches.count + " times = " + $phrase)
    }
}



# ----------------------------------------- LOG RESULTS ----------------------------------------- 

Write-Host ""
Write-Host "---Results Logged---"

if ($results.Length -gt 0) { # if error count is greater than 0
    foreach ($result in $results) {
        Write-Host $result
        $result | Out-File -FilePath $logFilePath -Append -Encoding UTF8 # Use Out-File to write to the log file
    }
} elseif ($results.Length -eq 0) { # if error count is 0
    $logMessage = "0 Errors Found, Incident NOT Sent to SNow." # Your message to be logged
    $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8  # Use Out-File to write to the log file
}



# ----------------------------------------- PASSWORD RESULTS ----------------------------------------- 

Write-Host ""
Write-Host "---Send Password Results (if error) ---"


# Writing Password Changed Results to Output Log File (if Error Count >= 1)

$errorMessage = "" # initialize error message
if ($results.Length -gt 0) { # if error count is greater than 0
    Write-Host "--- Yes Error ---"
    
    # Writing Password Changed Results, 1 of 3 options
    Write-Host "Password File : " $passwordFilePath
    Write-Host "Password File Exists: " $passwordFileExists
    if ($passwordFileExists -eq $false) { # if password file not found
        $errorMessage = "SNow Notification Failed and Password file was not found"       # error message for Service Now incident - Option 1
    } else { # if password file found
        $passwordFile = Get-Item -Path $passwordFilePath # retreive password file

        # -0 days when running script before midnight, ex, if today is 3/8/2024 11:55 pm, we want 3/8/2024 12:00 am
        # -1 days when running script after midnight, ex, if today is 3/9/2024 12:03 am, we want 3/8/2024 12:00 am
        # but 0 is probably what we want because PI data log data may not be available after midnight
        $yesterdayDate = [DateTime]::Today.AddDays(0) 
        $now = [DateTime]::Now
        $passwordModifiedAfterYesterday = $passwordFile.LastWriteTime.CompareTo($yesterdayDate) -eq 1
        $passwordModifiedAfterNow = $passwordFile.LastWriteTime.CompareTo($now) -eq 1

        if ($passwordModifiedAfterYesterday -eq $true) {                                 # If password file was changed since yesterday
            $errorMessage = "SNow Notification Failed and Password file was changed"     # error message for Service Now incident - Option 2
            $logMessage = "Password was modified since yesterday at " + $passwordFile.LastWriteTime # log message for output log file
        } else {                                                                         # If password file was not changed since yesterday
            $errorMessage = "SNow Notification Failed and Password file was not changed" # error message for Service Now incident - Option 3
            $logMessage = "Password was NOT modified since yesterday. Last Modified at " + $passwordFile.LastWriteTime # log message for output log file
        }
        
        $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8         # Use Out-File to write to the log file
    }



    if ($siteName.Length -gt 0 -and $locationName.Length -gt 0 -and $locationID.Length -gt 0 -and $errorMessage.Length -gt 0) {
        Write-Host "SEND INCIDENT FUNCTION"
        SendIncidentFunction $locationName $locationID $errorMessage # Send Incident Successfully, using included file SendIncidentFunction.ps1
    } else {
        $logMessage = "Unable to Send Incident, Check VARS siteName=" + $siteName + ", locationName=" + $locationName + ", locationID=" + $locationID + ", errorMessage=" + $errorMessage # Your message to be logged
        $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8  # Use Out-File to write to the log file
    }
} else {
    Write-Host "--- No Error ---"
}


# "" | Out-File -FilePath $logFilePath -Append -Encoding UTF8  # Add empty line to logs

# ----------------------------------------- DELETE OLD LOGS ----------------------------------------- 

Write-Host ""
Write-Host "--- Delete Old Logs? ---"
."C:\SNow Monitoring\DeleteOldLogs.ps1" # This also adds empty line
