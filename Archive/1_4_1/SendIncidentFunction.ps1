function SendIncidentFunction {
    
     Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $aFServername,
         [Parameter(Mandatory=$true, Position=1)]
         [string] $location_id,
         [Parameter(Mandatory=$true, Position=2)]
         [string] $errorMessage
         
    )

    #$location_id = "c2c821d1db726b0045b260535b961999" # TEST BELLEVUE

    Write-Host "VAR1: " $aFServername
    Write-Host "VAR2: " $location_id
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
        `"location`":         `"$location_id`",
        `"cmdb_ci`":          `"4f405367db5093404c04f5361d96194c`", 
        `"caller_id`":        `"cdc775e6db8620904c04f5361d96191d`", 
        `"assignment_group`": `"5880a5bddb6d9f40f9a0abc5ca9619f7`", 
        `"category`":         `"software`", 
        `"contact_type`":     `"Auto Generated`", 
        `"short_description`":`"TEST - SNow Monitoring - $aFServername`",
        `"description`":      `"$errorMessage`", 
        `"impact`":           `"3`", 
        `"urgency`":          `"3`"
        }"

    # Send HTTP request
    #$response = Invoke-RestMethod -Headers $headers -Method $method -Uri $uri -Body $body
    #Write-Host "RESPONSE: " $response.result
    # Print response
    #$response.RawContent
}


#$aFServername = "Hays Energy Facility" # site name
#$siteLocation = "4580d7b5db111300f9a0abc5ca9619aa"
#$errorMessage = "Test for Snow"
#SendIncidentFunction $aFServername $siteLocation $errorMessage # Send Incident Successfully, using included file SendIncidentFunction.ps1