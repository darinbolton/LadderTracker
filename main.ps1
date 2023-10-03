<#
.SYNOPSIS
    Queries SC2Pulse for StarCraft II ladder statistics
.NOTES
    Track ladder games from members of FxB and periodicly post in Discord if a user has won or lost 4 games in a row
.LINK
    https://github.com/sc2-pulse && https://github.com/darinbolton/LadderTracker
    https://sc2pulse.nephest.com/sc2/doc/swagger-ui/index.html?configUrl=/sc2/v3/api-docs/swagger-config#/character-controller/getCharacterSummary_1
#>

# Import NephestID, Race, and Name
$playerIDs = Import-Csv "C:\Users\Darin\Code\LadderTracker\NephestIDs.csv"
$date = Get-Date -Format "MM-dd-yyyy"

$playerIDs | ForEach-Object {
    $mmr = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/character/$($_.NephestID)/summary/1v1/7/$($_.Race)"`
    | ConvertFrom-Json `
    | Select-Object -Property $($_.Name),ratingLast `
    | Add-Content -Path "C:\Users\Darin\Code\LadderTracker\MMR\$date.txt"
}





#Write-Host "$($_.Name)"$mmr.ratingLast