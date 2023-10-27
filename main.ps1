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
    $gamesPlayed = $mmr.games
    
    $gamesPlayed = $mmr.games
    
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
    $apiResponses += $nameTrimmed + ";" + $row.Race + ";" + $mmr.ratingLast + ";" + $total.Sum
    
}
# Export API response to a .csv after converting results from a string
$apiResponses| ConvertFrom-String -Delimiter ";" -PropertyNames Name, Race, MMR, Games | Select-Object -Property Name, Race, MMR, Games | Export-Csv -Path .\MMR\$date.csv

# Import the CSV files
$previous = Import-Csv -Path .\MMR\$previousDay.csv
$current = Import-Csv -Path .\MMR\$date.csv

$differences = @()

# Loop through the rows and compare the MMR and games played values
for ($i = 0; $i -lt $current.Count; $i++) {
    $mmr1 = [int]$previous[$i].MMR
    $mmr2 = [int]$current[$i].MMR
    $games1 = [int]$previous[$i].Games
    $games2 = [int]$current[$i].Games
    
    # Calculates MMR difference between the two CSVs
    $difference = $mmr2 - $mmr1

    # Calculates games played in the last day
    $differenceGames = $games2 - $games1
    

    # Build new array to store values from both CSVs
    $result = New-Object PSObject -Property @{
        Player = $previous[$i].Name
        CurrentMMR = $mmr2
        PreviousMMR = $mmr1
        Change = $difference
        GamesPlayed = $differenceGames
        Race = $current[$i].Race         
    }

    # Add the result to the differences array
    $differences += $result
    }

# Display the differences
$sortedDifferences = $differences | Select-Object Player,CurrentMMR,PreviousMMR,Change,Race | Sort-Object -Property @{Expression = "Change"; Descending = $true}

# Initialize array to display only players with MMR changes
$playedOnly= @()

foreach ($player in $sortedDifferences) {
    if ($player.Change -ne 0){
        $playedOnly += $player
    }
}
$playedOnly | Export-Csv .\MMR\differences_$date.csv

if ($playedOnly[0].Change -gt '25'){
    '`' + $playedOnly[0].Player + '`' + " had a successful ladder session, moving up " + $playedOnly[0].Change + " MMR today!" | Out-File -Encoding ascii .\MMR\winner_$date.txt
}
if ($playedOnly[0].Change -gt '50'){
    '`' + $playedOnly[0].Player + '`' + " gained a respectable amount of MMR! They have moved up " + $playedOnly[0].Change + " MMR today!" | Out-File -Encoding ascii .\MMR\winner_$date.txt
}
if ($playedOnly[0].Change -gt '75'){
    '`' + $playedOnly[0].Player + '`' + " ...KILLING SPREE! They have feasted on the ladder today, gaining " + $playedOnly[0].Change + " MMR today!" | Out-File -Encoding ascii .\MMR\winner_$date.txt
}
if ($playedOnly[0].Change -gt '120'){
    '`' + $playedOnly[0].Player + '`' + " is gaining mo-fucking-mentum! They have moved up " + $playedOnly[0].Change + " MMR!" | Out-File -Encoding ascii .\MMR\winner_$date.txt
}
if ($playedOnly[0].Change -gt '175'){
    '`' + $playedOnly[0].Player + '`' + " ...Have you been smurfing? They've gained " + $playedOnly[0].Change + " MMR today, an absolutely staggering amount!" | Out-File -Encoding ascii .\MMR\winner_$date.txt
}
elseif ($playedOnly[0].Change -lt '25') {
    '`' + $playedOnly[0].Player + '`' + " gained a little MMR, or just sucked less than everyone else. They have moved up " + $playedOnly[0].Change + " MMR today!" | Out-File -Encoding ascii .\MMR\winner_$date.txt
}

# We went up, now lets go down
$bigLoser = $playedOnly | Select-Object -Last 1 

if ($bigLoser.Change -lt '0' -and $bigLoser.Change -lt '-25'){
    '`' + $bigLoser + '`' + " played a few games that didn't go their way, moving down " + $bigLoser.Change + " MMR today." | Out-File -Encoding ascii .\MMR\bigloser_$date.txt
}
if ($bigLoser.Change -lt '-50' -and $bigLoser.Change -lt '-26'){
    '`' + $bigLoser.Player + '`' + " probably forgot their coffee today, causing them to move down " + $bigLoser.Change + " MMR today." | Out-File -Encoding ascii .\MMR\bigloser_$date.txt
}
if ($bigLoser.Change -lt '-75' -and $bigLoser.Change -lt '-51'){
    '`' + $bigLoser.Player + '`' + " ...did you not sleep well? Forget to eat? Maybe take a nap, then try again... They've moved down " + $bigLoser.Change + " MMR today." | Out-File -Encoding ascii .\MMR\bigloser_$date.txt
}
if ($bigLoser.Change -lt '-100' -and $bigLoser.Change -lt '-76'){
    '`' + $bigLoser.Player + '`' + " is donating MMR to the ladder. First come, first serve! They've donated " + $bigLoser.Change + " MMR today." | Out-File -Encoding ascii .\MMR\bigloser_$date.txt
}
if ($bigLoser.Change -lt '-150' -and $bigLoser.Change -lt '-101'){
    '`' + $bigLoser.Player + '`' + " ...Alright. It's time to quit. Cut your losses, pack it up, and try another day. They've lost " + $bigLoser.Change + " MMR today, a brutal amount." | Out-File -Encoding ascii .\MMR\bigloser_$date.txt
}
if ($bigLoser.Change -lt '-200'  -and $bigLoser.Change -lt '-151'){
    '`' + $bigLoser.Player + '`' + " ...Is Galeforce your inspiration? Please stop. Get some help. They've lost " + $bigLoser.Change + " MMR today, an absolutely staggering amount." | Out-File -Encoding ascii .\MMR\bigloser_$date.txt
}
elseif ($bigLoser.Change -gt '-25') {
    '`' + $bigLoser.Player + '`' + " lost a little MMR, or was the lowest gainer. They have moved " + $bigLoser.Change + " MMR today." | Out-File -Encoding ascii .\MMR\bigloser_$date.txt
}
