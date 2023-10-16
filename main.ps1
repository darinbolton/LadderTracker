<#
.SYNOPSIS
    Queries SC2Pulse for StarCraft II ladder statistics
.NOTES
    Creates a leaderboard for Formless Bearsloths to track MMR gains and game count
.LINK
    https://github.com/sc2-pulse && https://github.com/darinbolton/LadderTracker
    https://sc2pulse.nephest.com/sc2/doc/swagger-ui/index.html?configUrl=/sc2/v3/api-docs/swagger-config#/character-controller/getCharacterSummary_1
#>

# Player ID's, name, and race are added in a separate CSV file. 
$playerIDs = Import-Csv .\NephestIDs.csv

# $date is used to name the exported CSV file, and $previousDay is used to reference the previous day's CSV. If you want to run this weekly instead of daily, adjust the -1 to -7. 
$date = Get-Date -Format "MM-dd-yyyy"
$previousDay = $(Get-Date).AddDays(-1).ToString("MM-dd-yyyy")

# Array we'll use to store results
$apiResponses = @()

foreach ($row in $playerIDs){

    $name = $row.Name
    $NephestID = $row.NephestID
    $race = $row.Race

    # Gets each player's current MMR and stores it in $mmr.ratingLast. Goes back 7 days, but can be adjusted by changing the number in front of $race.
    $mmrRequest = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/character/$NephestID/summary/1v1/7/$race"
    $mmr = $mmrRequest.Content | ConvertFrom-Json

    # MMR request doesn't return a name, so we have to query for name based on NephestID. 
    # Battletag is returned, so we'll trim everything in front of # and just use the name.
    $nameRequest = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/character/$NephestID"
    $name = $nameRequest.Content | ConvertFrom-Json
    $nameTrimmed = $name.name.Split('#')[0] 

    # Returns total number of games played in the last 7 days. Each race returns a different value, so we'll add them and let $total be the combined number. 
    $gamesRequest = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/character/$NephestID/summary/1v1/7"
    $games = $gamesRequest.Content | ConvertFrom-Json
    $total = $games.Games | Measure-Object -Sum

    # Add the API response to the array
    $apiResponses += $nameTrimmed + ";" + $mmr.ratingLast + ";" + $total.Sum
    
}
# Export API response to a .csv after converting results from a string
$apiResponses| ConvertFrom-String -Delimiter ";" -PropertyNames Name, MMR, Games | Select-Object -Property Name, MMR, Games | Export-Csv -Path .\MMR\$date.csv

# Import the CSV files
$previous = Import-Csv -Path .\MMR\$previousDay.csv
$current = Import-Csv -Path .\MMR\$date.csv

$differences = @()

# Loop through the rows and compare the MMR values
for ($i = 0; $i -lt $current.Count; $i++) {
    $mmr1 = [int]$previous[$i].MMR
    $mmr2 = [int]$current[$i].MMR
    $games1 = [int]$previous[$i].Games
    $games2 = [int]$current[$i].Games
    

    $difference = $mmr2 - $mmr1
    $differenceGames = $games1 - $games2
    if ($differenceGames -lt 0){
        $differenceGames = 0
    }

    $result = New-Object PSObject -Property @{
        Player = $previous[$i].Name
        CurrentMMR = $mmr2
        PreviousMMR = $mmr1
        Change = $difference
        GamesPlayed = $differenceGames
    }

    # Add the result to the differences array
    $differences += $result
    }

# Display the differences
$differences | Select-Object Player,CurrentMMR,PreviousMMR,Change,GamesPlayed | ft -AutoSize