# Get dates. $date is used for the file, $day is used for the bot message
$date = Get-Date -Format "MM-dd-yyyy"
$day = Get-Date -Format "dddd MM/dd/yyyy HH:mm"

# Discord webhook uri's


$winnerMessage = Get-Content .\MMR\winner_$date.txt
$loserMessage = Get-Content .\MMR\bigLoser_$date.txt
$leaderboard = Import-Csv -Path .\MMR\differences_$date.csv
 
$webhookURL = Get-Content ..\webhookURL.txt

# Create embed array
[System.Collections.ArrayList]$embedArray = @()

# Store embed values
$title       = "Ladder Leaderboard for $day"
$description = $winnerMessage + " " + $loserMessage

# Format the CSV data as a table in a code block
$csvDescription = '`' + ($leaderboard | Format-Table | Out-String)+'`'

# Create thumbnail object
$thumbUrl = 'https://github.com/darinbolton/LadderTracker/blob/main/FxB.png?raw=true'
$thumbnailObject = [PSCustomObject]@{
    url = $thumbUrl
}

$footerObject = [PSCustomObject]@{
    text = "This bot is maintained by Galeforce."
}

# Create embed object, also adding thumbnail
$embedObject = [PSCustomObject]@{

    title       = $title
    description = $description + "`n`n" + "$csvDescription"
    color       = '8716543'
    thumbnail   = $thumbnailObject
    footer      = $footerObject
}

# Add embed object to array
$embedArray.Add($embedObject) | Out-Null

# Create the payload
$payload = [PSCustomObject]@{

    embeds = $embedArray

}

# Send over payload, converting it to JSON
Invoke-RestMethod -Uri $webhookURL -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'
