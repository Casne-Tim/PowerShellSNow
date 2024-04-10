"C:\SNow Monitoringl\SendIncidentFunction.ps1" # include SendIncidentFunction.ps1 file


$aFServername = "Hays Energy Facility" # site name

$logFilePath = "C:\SNow Monitoring\Logs.txt" # Log file for output logs

$csvFilePath = "C:\SNow Monitoring\location_id_table.csv" # CSV file that should have 2 columns: location, location_ID

$passwordFilePath = "C:\ProgramData\OSIsoft\PINotifications\Data\" +$aFServername + "\Credentials\credentials.dat" # Password file path
#$passwordFilePath = "C:\ProgramData\OSIsoft\PINotifications\Data\Decordova\Credentials\credentials.dat" # Password file path
$passwordFileExists = Test-Path $passwordFilePath

$notifFilePath = (Join-Path $env:ProgramData "OSIsoft\PINotifications\Logs") + "\" + "pinotifications-log.txt" # PI Notification Logs file path
Write-Host($notifFilePath)
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

# Searching the PI Notification Logs for Desired Phrases

$desiredPhrases = @("Error:", "Error: SMTP:NoToEmail", "401 (Unauthorized).") # desired search phrases
Write-Host "Notification Log File: " $notifFilePath
Write-Host "Notification Log File Ex: " $notifFilePath
$logs = Get-Content $notifFilePath  -Raw          # read entire log file as a string
$log_words = -split $logs                        # split log file into array of words by space delimeter

$results = @()                                   # add the found phrases results to this array
for ($i=0; $i -lt $desiredPhrases.Count; $i++) { # for each desired phrase
    $phrase = $desiredPhrases[$i]                # desiredPhrase, ex: "Error: SMTP:NoToEmail"
    $phrase_words = -split $phrase               # split the desiredPhrase, ex: ["Error:", "SMTP:NoToEmail"]
    for ($j=0; $j -lt $log_words.Count; $j++) {  # for each word in logs
        $k = 0                                   # to iterate over words in the desired phrase array
        # if matching words are found, keep going to the next word and check all the words in the desired phrase
        while (($k -lt $phrase_words.Count) -and ($phrase_words[$k] -eq $log_words[$j + $k])) {
            $k++                                 # increment in desired phrase array while words are matching (partial match)
        }
        # if k is the same length as the desired phrase array that means all the words matched in the phrase
        if ($k -eq $phrase_words.Count) {
            $results += $phrase                  # save phrase (full match)
        }
    }
}
$resultsCount = $results.Count                   # Count the results (i.e. phrases that matches)

# Writing Search Results to Output Log File

$logMessage = "[$resultsCount] Errors Found"     # Your message to be logged
$logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8 # Use Out-File to write to the log file
$error_count = 0
Foreach ($result in $results) {
    $logMessage = "Error " + ++$error_count + ": " + $result # Your message to be logged
    $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8 # Use Out-File to write to the log file
}

# Writing Password Changed Results to Output Log File (if Error Count >= 1)

$errorMessage = "" # initialize error message
if ($resultsCount -gt 0) { # if error count is greater than 0
    
    
    # Writing Password Changed Results, 1 of 3 options
    Write-Host "Password File : " $passwordFilePath
    Write-Host "Password File Exists: " $passwordFileExists
    $passwordFileExists
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

    
    # Getting Location ID if available, if not write to logs, if yes send Incident to SNow
    # example: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv?view=powershell-7.4
    $P = Import-Csv -Path $csvFilePath -Header 'Location', 'ID'
    $P | Get-Member
    $P | Format-Table
    $siteLocation = $P | Where-Object -Property Location -Like $aFServername


    if ($aFServername.Length -gt 0 -and $siteLocation.ID.Length -gt 0 -and $errorMessage.Length -gt 0) {
        #SendIncidentFunction $aFServername $siteLocation.ID $errorMessage # Send Incident Successfully, using included file SendIncidentFunction.ps1
        Write-Host "TEST SEND FUNCTUION HER"

    } else {
        $logMessage = "Unable to Send Incident, Check VARS: aFServername: " + $aFServername + " siteLocation.ID: " + $siteLocation.ID + " errorMessage:" + $errorMessage # Your message to be logged
        $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8  # Use Out-File to write to the log file
    }


}




