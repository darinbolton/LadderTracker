<#
.SYNOPSIS
    Queries SC2Pulse for StarCraft II ladder statistics
.NOTES
    Track ladder games from members of FxB and periodicly post in Discord if a user has won or lost 4 or more games in a row
.LINK
    https://github.com/sc2-pulse && https://github.com/darinbolton/LadderTracker
    https://sc2pulse.nephest.com/sc2/doc/swagger-ui/index.html?configUrl=/sc2/v3/api-docs/swagger-config#/character-controller/getCharacterSummary_1
#>

# Values
$FxBID = "1865"

$Gale = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/character/18288/summary/1v1/90/PROTOSS" | ConvertFrom-Json
$FxB = Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/group/character/full?clanId=1865" | ConvertFrom-Json | ft 

Invoke-WebRequest -Uri "https://sc2pulse.nephest.com/sc2/api/group/character/full?clanId=1865"