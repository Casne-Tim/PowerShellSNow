#
$aFServername = "Decordova"

# Specify the log file path
$logFilePath = "C:\SNow Monitoring\Logs.txt" 

# Get the current date and time in a specific format
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Your message to be logged
$logMessage = "--- Powershell Start Time [$timestamp] ---"

# Use Out-File to write to the log file
$logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8


#Tim - Search Notification Log for Errors

# Creating filepath for Notification File
$notifFilePath = Join-Path $env:ProgramData "OSIsoft\PINotifications\Logs"
$filePathName = $notifFilePath + "\" + "pinotifications-log.txt"

# Check if File Exists, If Not Exit
$fileExists = Test-Path $filePathName
if ($fileExists -eq $false) {
    $logMessage =  "File not found at $filePathName."
    $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8
    Exit
} 

#Search phrases
$desiredPhrases = @("Error:", "Error:     SMTP:NoToEmail")


$logs = Get-Content $filePathName  -Raw # read entire log file as a string
$log_words = -split $logs               # split log file into array of words


$results = @()                          # add the found phrases results to this array
# for each desired phrase
for ($i=0; $i -lt $desiredPhrases.Count; $i++) {
    $phrase = $desiredPhrases[$i]       # desiredPhrase, ex: "Error: SMTP:NoToEmail"
    $phrase_words = -split $phrase      # split the desiredPhrase, ex: ["Error:", "SMTP:NoToEmail"]
    # for each word in logs
    for ($j=0; $j -lt $log_words.Count; $j++) {
        $k = 0                          # to iterate over words in the desired phrase array
        # if matching words are found, keep going to the next word and check all the words in the desired phrase
        while (($k -lt $phrase_words.Count) -and ($phrase_words[$k] -eq $log_words[$j + $k])) {
            #Write-Host "FOUND PARTIAL MATCH:" + $phrase_words[$k]  
            $k++
        }
        # if k is the same length as the desired phrase array that means all the words matched in the phrase
        if ($k -eq $phrase_words.Count) {
            #Write-Host "FOUND FULL MATCH:" + $phrase
            $results += $phrase
        }
    }
}

$resultsCount = $results.Count          # Count the results (i.e. phrases that matches)
<#
Write-Host "Total Results Found: " $resultsCount
Foreach ($result in $results) {
    Write-Host "Found: " + $result      # Print results to console
}
#>

# Print results to Log File

# Your message to be logged
$logMessage = "[$resultsCount] Errors Found"
# Use Out-File to write to the log file
$logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8
$error_count = 0
Foreach ($result in $results) {
    # Your message to be logged
    $logMessage = "Error " + ++$error_count + ": " + $result
    # Use Out-File to write to the log file
    $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8
}


#If errors are found, check if the Password file has changed
if ($resultsCount -gt 0) {

    $passwordFilePath = "C:\ProgramData\OSIsoft\PINotifications\Data\Decordova\Credentials\credentials.dat"
    $passwordFile = Get-Item -Path $passwordFilePath


    $yesterdayDate = [DateTime]::Today.AddDays(-1) # ex, if today is 3/8/2024 12:03 am, we want 3/7/2024 12:00 am
    $now = [DateTime]::Now
    $passwordModifiedAfterYesterday = $passwordFile.LastWriteTime.CompareTo($yesterdayDate) -eq 1
    $passwordModifiedAfterNow = $passwordFile.LastWriteTime.CompareTo($now) -eq 1

    # Print to Console to Check Dates
    <#
    Write-Host "Yesterday Date: " $yesterdayDate
    Write-Host "Password File Date: " $passwordFile.LastWriteTime
    Write-Host "Now Date: " $now
    Write-Host "Password Modified After Yesterday: " $passwordModifiedBeforeYesterday
    Write-Host "Password Modified After Now: " $passwordModifiedBeforenow
    #>

    # If password file was changed since yesterday, Write it to Log File
    if ($passwordModifiedAfterYesterday -eq $true) {
        # Your message to be logged
        $logMessage = "Password was modified since yesterday at " + $passwordFile.LastWriteTime
        # Use Out-File to write to the log file
        $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8
    }
}


