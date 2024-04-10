."C:\SNow Monitoring\SendIncidentFunction.ps1" # include SendIncidentFunction.ps1 file





# ----------------------------------------- CONFIG ----------------------------------------- 


$computerName = $env:computername | Select-Object # AF computer name
#$computerName = "HAY"

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
#$passwordFilePath = "C:\ProgramData\OSIsoft\PINotifications\Data\Decordova\Credentials\credentials.dat" # Password file path
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

# Initialize variables for Search
# The idea is the keep track of which index each char occurs at and then we can use that as the starting indices in our search
$dic = @{}             # dictionary for each char in logs with char_i and line_#, ex: "e" : [(1, 1), (4, 1), (18, 2)], if letter "e" is found 3 times at i=1, 4, 18 on line=1,1,2  
$i = 0                 # to count the char #
$line_count = 0        # to count the line #

# Populate the dictionary and logs
foreach ($c in $logs.ToCharArray()) {  # for each char in the $logs string array
    if (-not $dic.ContainsKey($c)) {   # if char is not yet in dictionary
        $dic[$c] = @()                 # add it with a blank array, ex: "e" : []
    }
    $dic[$c] += ,($i, $line_count)     # add to dictionary char# & line#, ex: [(1, 1), (4, 1), (18, 2)]

    $i++               # increment char # count
    if ($c -eq "`n") { # if char is new line
        $line_count++  # increment line # count
    }
}
$i_max = $i # limit of our logs, i can only be less than this to stay in bounds

# Define desired search phrases
$desiredPhrases = @("Error:", "Error: SmTP:NoToEmail", "401 (unauthorized).")

$results = @() # search results array
foreach ($phrase in $desiredPhrases) {                 # for each phrase in desired phrases
    if ($phrase.Length -gt 0) {                        # only attempt non empty phrases
        $i_starts = @()                                # potential char# for to start search in the logs at this index, will add values from dictionary
        $line_counts = @()                             # potential line# in case we find a match and want to know which line, will add values from dictionary
        if ($dic.ContainsKey($phrase[0])) {            # for each pair of (char#, line#) in the dictionary, the char# is to start the search there, and if match found then save the line#
            foreach ($pair in $dic[$phrase[0]]) {      # ex, pair= (18,2)
                $i_starts += $pair[0]                  # char#, ex: 18
                $line_counts += $pair[1]               # line#, ex: 2
            }
        }

        # for each potential i (char#) where the char occurs, start the search there
        for ($idx = 0; $idx -lt $i_starts.Count; $idx++) {
            $j = 0          # to loop the chars in $phrase
            $match = $false # to check if chars in $phrase and the $logs match as we loop through the phrase
            # first time the while loop should enter always
            while ($j -eq 0 -or ($j -lt $phrase.Length -and $i_starts[$idx] + $j -lt $i_max -and $match -eq $true)) {
                
                $a = "" + $phrase[$j]
                $a = $a.ToLower()
                $b = "" + $logs[$i_starts[$idx] + $j]
                $b = $b.ToLower()
                $match = $a -eq $b # chars match 
                $j++
            }
            # if j is the same length as the desired phrase array that means all the chars matched in the phrase
            if ($j -eq $phrase.Length) {
                $results += ,("Error " + ($results.Count +1) + " found on line " + $($line_counts[$idx]) + " = " + $($logs.Substring($i_starts[$idx], $j)))
            }
        }
    }
}

foreach ($result in $results) {
    Write-Host $result
    $result | Out-File -FilePath $logFilePath -Append -Encoding UTF8 # Use Out-File to write to the log file
}




# ----------------------------------------- PASSWORD RESULTS ----------------------------------------- 




# Writing Password Changed Results to Output Log File (if Error Count >= 1)

$errorMessage = "" # initialize error message
if ($result.Length -gt 0) { # if error count is greater than 0
    
    
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
        #SendIncidentFunction $locationName $locationID $errorMessage # Send Incident Successfully, using included file SendIncidentFunction.ps1
    } else {
        $logMessage = "Unable to Send Incident, Check VARS siteName=" + $siteName + ", locationName=" + $locationName + ", locationID=" + $locationID + ", errorMessage=" + $errorMessage # Your message to be logged
        $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8  # Use Out-File to write to the log file
    }
}
"" | Out-File -FilePath $logFilePath -Append -Encoding UTF8  # Add empty line to logs

# ----------------------------------------- DELETE OLD LOGS ----------------------------------------- 


."C:\SNow Monitoring\DeleteOldLogs.ps1"
