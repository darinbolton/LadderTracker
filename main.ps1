<#
.SYNOPSIS
    Queries SC2Pulse for StarCraft II ladder statistics
.NOTES
    Track ladder games from members of FxB and periodicly post in Discord if a user has won or lost 4 games in a row
.LINK
    https://github.com/sc2-pulse && https://github.com/darinbolton/LadderTracker
    https://sc2pulse.nephest.com/sc2/doc/swagger-ui/index.html?configUrl=/sc2/v3/api-docs/swagger-config#/character-controller/getCharacterSummary_1
#>

$playerIDs = Import-Csv .\NephestIDs.csv
$date = Get-Date -Format "MM-dd-yyyy"

$apiResponses = @()

foreach ($row in $playerIDs){

    $name = $row.Name
    $NephestID = $row.NephestID
    $race = $row.Race
    $response = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/character/$NephestID/summary/1v1/7/$race"
    $response1 = $response.Content | ConvertFrom-Json
    $mmr = $response1.ratingLast

    $nameRequest = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/character/$NephestID"
    $name = $nameRequest.Content | ConvertFrom-Json

    # Add the API response to the array
    $apiResponses += $name.Name + ";" + $response1.ratingLast
    
}

$apiResponses| ConvertFrom-String -Delimiter ";" -PropertyNames Name, MMR | Select-Object -Property Name, MMR | Export-Csv -Path .\MMR\$date.csv