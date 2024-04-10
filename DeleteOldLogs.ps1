# Define the file path
$file_path = "C:\SNow Monitoring\Logs.txt"

# Read the file
$logs = Get-Content -Path $file_path -Raw # read logs as a raw string

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
$desiredPhrases = @("--- Powershell Start Time [")

$results = @() # search results array
$idx_save_first_recent_log = -1
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
                $j++
                $a = "" + $phrase[$j]
                $a = $a.ToLower()
                $b = "" + $logs[$i_starts[$idx] + $j]
                $b = $b.ToLower()
                $match = $a -eq $b # chars match 
            }
            # if j is the same length as the desired phrase array that means all the chars matched in the phrase
            if ($j -eq $phrase.Length) {
                $timestamp_string =  $($logs.Substring($i_starts[$idx] + $phrase.Length , "yyyy-MM-dd HH:mm:ss".Length))
                $timestamp = [DateTime]$timestamp_string 
                $results += ,(  $timestamp  )
                
                $oldestDateToKeep = [DateTime]::Today.AddDays(-180) 
                #$oldestDateToKeep = [DateTime]"2024-03-22 02:17:12" # for TEST
                $now = [DateTime]::Now
                $logIsRecent = $timestamp.CompareTo($oldestDateToKeep) -ne -1        # recent log means within the last 6 months
                if ($logIsRecent -eq $true -and $idx_save_first_recent_log -lt 0) {  # save index of first recent log
                    $idx_save_first_recent_log = $i_starts[$idx]
                    Write-Host "First Recent Log found at idx_save_first_recent_log =" $idx_save_first_recent_log
                }
            }
        }
    }
}


$idx_save_first_recent_log = [Math]::Max($idx_save_first_recent_log, 0) # just in case, make sure index is 0 if most recent log was not found

# logs starting from the most recent log index until the end of the file, overwrite the previous log
$logMessage = $logs.Substring($idx_save_first_recent_log , $i_max - $idx_save_first_recent_log)
$logMessage | Out-File -FilePath $file_path -Encoding UTF8  # Use Out-File to write to the log file

