function SendIncidentFunction {
    
     Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $locationName,
         [Parameter(Mandatory=$true, Position=1)]
         [string] $locationID,
         [Parameter(Mandatory=$true, Position=2)]
         [string] $errorMessage
         
    )

    #$locationID = "c2c821d1db726b0045b260535b961999" # TEST BELLEVUE

    Write-Host "VAR1: " $locationName
    Write-Host "VAR2: " $locationID
    Write-Host "VAR3: " $errorMessage

    # Eg. User name="admin", Password="admin" for this code sample.
    $user = "PI.Integrator"
    $pass = "P3@ChE14I6"

    # Build auth header
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, $pass)))

    # Set proper headers
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add('Authorization',('Basic {0}' -f $base64AuthInfo))
    $headers.Add('Accept','application/json')
    $headers.Add('Content-Type','application/json')

    # Specify endpoint uri
    $uri = "https://vistra.service-now.com/api/now/table/incident"

    # Specify HTTP method
    $method = "post"

    # Specify request body
    $body = "{
        `"location`":         `"$locationID`",
        `"cmdb_ci`":          `"4f405367db5093404c04f5361d96194c`", 
        `"caller_id`":        `"cdc775e6db8620904c04f5361d96191d`", 
        `"assignment_group`": `"5880a5bddb6d9f40f9a0abc5ca9619f7`", 
        `"category`":         `"software`", 
        `"contact_type`":     `"Auto Generated`", 
        `"short_description`":`"TEST - SNow Monitoring - $locationName`",
        `"description`":      `"$errorMessage`", 
        `"impact`":           `"3`", 
        `"urgency`":          `"3`"
        }"

    # Send HTTP request
    $response = Invoke-RestMethod -Headers $headers -Method $method -Uri $uri -Body $body
    Write-Host "RESPONSE: " $response.result

    # Print response
    $response.RawContent
}

# for TEST
#$locationName = "Bellingham Energy Facility" # site name
#$locationID = "c2c821d1db726b0045b260535b961999" # TEST BELLEVUE
#$errorMessage = "TEST"
#SendIncidentFunction $locationName $locationID $errorMessage # Send Incident Successfully, using included file SendIncidentFunction.ps1