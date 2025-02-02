<#
.SYNOPSIS
    Queries SC2Pulse for StarCraft II ladder statistics
.NOTES
    Creates a leaderboard for Formless Bearsloths to track MMR gains and game count
.LINK
    https://github.com/sc2-pulse && https://github.com/darinbolton/LadderTracker
    https://sc2pulse.nephest.com/sc2/doc/swagger-ui/index.html?configUrl=/sc2/v3/api-docs/swagger-config#/character-controller/getCharacterSummary_1
#>

# $date is used to name the exported CSV file, and $previousDay is used to reference the previous day's CSV. If you want to run this weekly instead of daily, adjust the -1 to -7. 
$date = Get-Date -Format "MM-dd-yyyy"
$previousDay = $(Get-Date).AddDays(-1).ToString("MM-dd-yyyy")

Start-Transcript -Path .\Logs\logs-$date.txt

# Player ID's, name, and race are added in a separate CSV file. 
$playerIDs = Import-Csv .\NephestIDs.csv

# Array we'll use to store results
$apiResponses = @()

foreach ($row in $playerIDs){

    $name = $row.Name
    $NephestID = $row.NephestID
    $race = $row.Race
    $llid = $row.LLID

    # Gets each player's current MMR and stores it in $mmr.ratingLast. Goes back 7 days, but can be adjusted by changing the number in front of $race.
    $mmrRequest = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/character/$NephestID/summary/1v1/7/$race"
    $mmr = $mmrRequest.Content | ConvertFrom-Json
    $gamesPlayed = $mmr.games
    $ratingMax = $mmr.ratingMax
    $ratingLast = $mmr.ratingLast
    Write-Verbose "Getting MMR data for $name's $race /// MMR: $ratingLast /// Games Played: $gamesPlayed" -Verbose
    
    # MMR request doesn't return a name, so we have to query for name based on NephestID. 
    # Battletag is returned, so we'll trim everything in front of # and just use the name.
    $nameRequest = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/character/$NephestID"
    $name2 = $nameRequest.Content | ConvertFrom-Json
    $nameTrimmed = $name2.name.Split('#')[0] 
    #Write-Verbose "Getting name data for $name | $race." -Verbose

    # Returns total number of games played in the last 7 days. Each race returns a different value, so we'll add them and let $total be the combined number. 
    $gamesRequest = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/character/$NephestID/summary/1v1/7"
    $games = $gamesRequest.Content | ConvertFrom-Json
    $total = $games.Games | Measure-Object -Sum

    # Highest MMR
    $ath = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/character/$NephestID/summary/1v1/5000/$race"
    $highmmr = $ath.Content | convertfrom-json
    $ATHmmr = $highmmr.RatingMax
    

    # Winner only NephestID
    #$winnerNephest = $playedOnly[0].NephestID

    # API call to get match history 
    $getMatches = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/group/match?typeCursor=_1V1&mapCursor=0&regionCursor=US&type=_1V1&limit=25&characterId=$NephestID"
    $ladderMatches = $getMatches.Content | ConvertFrom-Json
    Write-Verbose "Getting information about the last 25 games played for $name." -Verbose

    # API call continued
    $last25 = $ladderMatches.Participants.Participant | Select-Object playercharacterid, decision, ratingchange | Where-Object {$_.PlayerCharacterID -eq $NephestID}

    # Gets total number of wins in last 25
    $wins = $last25 | Where-Object {$_.PlayerCharacterID -eq $NephestID -and $_.decision -eq 'WIN'}
    $bestWin = ($last25 | Measure-Object -Property ratingchange -Maximum).Maximum
    $winP = $wins.Count / 25
    $winPercent = $winP.ToString("P")

    # Last 25 games are shown with most recent being at the top. To read properly, this needs to be at the bottom, so we flip it.
    #[array]::Reverse($last25)

    $wS = 0
    $maxWS = 0

    foreach ($match in $last25) {
        if ($match.decision -eq 'WIN') {
            $wS++
            if ($wS -gt $maxWS) {
                $maxWS = $wS
            }
        } else {
            $wS = 0
        }
    }

    $lS = 0
    $maxlS = 0

    foreach ($match in $last25) {
        if ($match.decision -eq 'LOSS') {
            $ls++
            if ($ls -gt $maxlS) {
                $maxlS = $lS
            }
        } else {
            $lS = 0
        }
    }

    # Add the API response to the array
    $apiResponses += $nameTrimmed + ";" + $row.Race + ";" + $mmr.ratingLast + ";" + $total.Sum + ";" + $NephestID + ";" + $maxWS + ";" + $maxlS + ";" + $ratingMax + ";" + $llid + ";" + $winPercent
    
}
# Export API response to a .csv after converting results from a string
$apiResponses | ConvertFrom-String -Delimiter ";" -PropertyNames Name, Race, MMR, Games, NephestID, maxWS, maxlS, ratingMax, LLID, winPercent | Select-Object -Property Name, Race, MMR, Games, NephestID, maxWS, maxlS, ratingMax, LLID, winPercent | Export-Csv -Path .\MMR\AllPartipants\$date.csv -NoTypeInformation

$apiResponses | ConvertFrom-String -Delimiter ";" -PropertyNames Name, Race, MMR, Games, NephestID, maxWS, maxlS, ratingMax, LLID, winPercent | Select-Object -Property Name, Race, MMR, Games, NephestID, maxWS, maxlS, ratingMax, LLID, winPercent | Export-Csv -Path .\MMR\AllPartipants\AllPartipantsSQL.csv -NoTypeInformation

# /// Updates LadderStaging SQL table with contents from AllParticipantsSQL.csv ///
Invoke-Sqlcmd -ServerInstance "WINDOWSSERVER\SQLEXPRESS" -Database 'FxB_LadderLeaderboard' -Encrypt Optional -Query @"
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'LadderStaging')
    DROP TABLE LadderStaging;

CREATE TABLE LadderStaging (
    Name VARCHAR(255),
    Race VARCHAR(255),
    MMR INT,
    Games INT,
    NephestID INT,
    MaxWS INT,
    MaxLS INT,
    RatingMax INT,
    LLID VARCHAR(255) PRIMARY KEY,
    WinPercent varchar(10)
);

BULK INSERT LadderStaging
FROM 'C:\Programs\LadderTracker\MMR\AllPartipants\AllPartipantsSQL.csv'
WITH (
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    FIELDQUOTE = '"',
    ROWTERMINATOR = '
',
    FIRSTROW = 2
);
"@

Invoke-Sqlcmd -ServerInstance "WINDOWSSERVER\SQLEXPRESS" -Database 'FxB_LadderLeaderboard' -Encrypt Optional -Query @"
INSERT INTO AllParticipants (LLID, Name, MMR, Race, Games, NephestID, MaxWS, MaxLS, RatingMax, WinPercent)
SELECT
    LadderStaging.LLID,
    LadderStaging.Name,
    LadderStaging.MMR,
    LadderStaging.Race,
    LadderStaging.Games,
    LadderStaging.NephestID,
    LadderStaging.MaxWS,
    LadderStaging.MaxLS,
    LadderStaging.RatingMax,
    LadderStaging.WinPercent
FROM
    LadderStaging
LEFT JOIN
    AllParticipants ON LadderStaging.LLID = AllParticipants.LLID
WHERE
    AllParticipants.LLID IS NULL;
"@


# /// Gets differences between LadderStaging db and AllParticipants db. This is table that should be posting to Discord. ///
$table = Invoke-Sqlcmd -ServerInstance "WINDOWSSERVER\SQLEXPRESS" -Database 'FxB_LadderLeaderboard' -Encrypt Optional -Query @"
SELECT 
    COALESCE(LS.LLID, APS.LLID) AS LadderID,
	LS.Name,
	LS.Race,
    LS.MMR AS MMR,
    APS.MMR AS PrevMMR,
    LS.MMR - APS.MMR AS Change,
	LS.MaxWS,
	LS.MaxLS,
	LS.RatingMax,
	LS.WinPercent

FROM 
    LadderStaging LS
FULL OUTER JOIN 
    AllParticipants APS ON LS.LLID = APS.LLID
WHERE 
    LS.MMR IS NOT NULL AND APS.MMR IS NOT NULL AND LS.MMR <> APS.MMR;
"@

# /// Gets differences between LadderStaging db and AllParticipants db. This is table that should be posting to Discord. ///
$table | Select-Object -Property Name,Race,MMR,PrevMMR,Change,MaxWS,MaxLS,RatingMax,WinPercent |  Sort-Object -Property @{Expression = "Change"; Descending = $true} | Export-Csv -Path .\SQLOutput\AllParticipants.csv -NoTypeInformation
$playedOnly = $table | Select-Object -Property Name,Race,MMR,PrevMMR,Change,MaxWS,MaxLS,RatingMax,WinPercent |  Sort-Object -Property @{Expression = "Change"; Descending = $true}

if ($playedOnly[0].Change -gt '1'){
    '`' + $playedOnly[0].Name + '`' + " had a successful ladder session, moving up " + '`' + $playedOnly[0].Change + '`' + " MMR today!" | Out-File -Encoding ascii .\MMR\DailyWinner\winner_$date.txt
}
if ($playedOnly[0].Change -gt '25'){
    '`' + $playedOnly[0].Name + '`' + " had a successful ladder session, moving up " + '`' + $playedOnly[0].Change + '`' + " MMR today!" | Out-File -Encoding ascii .\MMR\DailyWinner\winner_$date.txt
}    
if ($playedOnly[0].Change -gt '50'){
    '`' + $playedOnly[0].Name + '`' + " gained a respectable amount of MMR! They have moved up " + '`' + $playedOnly[0].Change + '`' + " MMR today!" | Out-File -Encoding ascii .\MMR\DailyWinner\winner_$date.txt
}
if ($playedOnly[0].Change -eq '69'){
    '`' + $playedOnly[0].Name + '`' + " gained " + '`' + $playedOnly[0].Change + '`' + " MMR today... niiiiiiiiiiice. ;)" | Out-File -Encoding ascii .\MMR\DailyWinner\winner_$date.txt
}
if ($playedOnly[0].Change -gt '75'){
    '`' + $playedOnly[0].Name + '`' + " ...KILLING SPREE! They have feasted on the ladder today, gaining " + '`' + $playedOnly[0].Change + '`' + " MMR today!" | Out-File -Encoding ascii .\MMR\DailyWinner\winner_$date.txt    
}
if ($playedOnly[0].Change -gt '100'){
    '`' + $playedOnly[0].Name + '`' + " learned a new build, they've gained " + '`' + $playedOnly[0].Change + '`' + " MMR today!" | Out-File -Encoding ascii .\MMR\DailyWinner\winner_$date.txt    
}
if ($playedOnly[0].Change -gt '120'){
    '`' + $playedOnly[0].Name + '`' + " is gaining momentum! They have moved up " + '`' + $playedOnly[0].Change + '`' + " MMR!" | Out-File -Encoding ascii .\MMR\DailyWinner\winner_$date.txt
}
if ($playedOnly[0].Change -gt '175'){
    '`' + $playedOnly[0].Name + '`' + " ...Have you been smurfing? They've gained " + '`' + $playedOnly[0].Change + '`' + " MMR today, an absolutely staggering amount!" | Out-File -Encoding ascii .\MMR\DailyWinner\winner_$date.txt
}
elseif ($playedOnly[0].Change -lt '25') {
    '`' + $playedOnly[0].Name + '`' + " gained a little MMR, or just sucked less than everyone else. They have moved up " + '`' + $playedOnly[0].Change + '`' + " MMR today!" | Out-File -Encoding ascii .\MMR\DailyWinner\winner_$date.txt
}

# We went up, now lets go down
$bigLoser = $playedOnly | Select-Object -Last 1 

if ($bigLoser.Change -lt '0' -and $bigLoser.Change -lt '-25'){
    '`' + $bigLoser.Name + '`' + " played a few games that didn't go their way, moving down " + '`' + $bigLoser.Change + '`' + " MMR today." | Out-File -Encoding ascii .\MMR\DailyLoser\bigLoser_$date.txt
}
if ($bigLoser.Change -lt '-50' -and $bigLoser.Change -lt '-26'){
    '`' + $bigLoser.Name + '`' + " probably forgot their coffee today, causing them to move down " + '`' + $bigLoser.Change + '`' + " MMR today." | Out-File -Encoding ascii .\MMR\DailyLoser\bigLoser_$date.txt
}
if ($bigLoser.Change -lt '-75' -and $bigLoser.Change -lt '-51'){
    '`' + $bigLoser.Name + '`' + " ... Your MMR is in another castle. You've lost " + '`' + $bigLoser.Change + '`' + " MMR today." | Out-File -Encoding ascii .\MMR\DailyLoser\bigLoser_$date.txt
}
if ($bigLoser.Change -lt '-100' -and $bigLoser.Change -lt '-76'){
    '`' + $bigLoser.Name + '`' + " is donating MMR to the ladder. First come, first serve! They've donated " + '`' + $bigLoser.Change + '`'  + " MMR today." | Out-File -Encoding ascii .\MMR\DailyLoser\bigLoser_$date.txt
}
if ($bigLoser.Change -lt '-150' -and $bigLoser.Change -lt '-101'){
    '`' + $bigLoser.Name + '`' + " ...Alright. It's time to quit. Cut your losses, pack it up, and try another day. They've lost "  + '`' + $bigLoser.Change + '`' + " MMR today, a brutal amount." | Out-File -Encoding ascii .\MMR\DailyLoser\bigLoser_$date.txt
}
if ($bigLoser.Change -lt '-200'  -and $bigLoser.Change -lt '-151'){
    '`' + $bigLoser.Name + '`' + " ...Is this a Barcode moment? Please stop. Get some help. They've lost "  + '`' + $bigLoser.Change + '`' + " MMR today, an absolutely staggering amount." | Out-File -Encoding ascii .\MMR\DailyLoser\bigLoser_$date.txt
}
elseif ($bigLoser.Change -gt '0') {
    '`' + $bigLoser.Name + '`' + " made forward progress, but not as much as everyone else!. They have moved up "  + '`' + $bigLoser.Change + '`' + " MMR today!" | Out-File -Encoding ascii .\MMR\DailyLoser\bigLoser_$date.txt
}

$playedOnly | ft 
