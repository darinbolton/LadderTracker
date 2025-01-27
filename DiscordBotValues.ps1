# Get dates. $date is used for the file, $day is used for the bot message
$date = Get-Date -Format "MM-dd-yyyy"
$day = Get-Date -Format "dddd MM/dd/yyyy HH:mm"
$prettyday = Get-Date -Format "dddd, MM/dd"

# Discord webhook uri's
$webhookURL = Get-Content ..\webhookURL.txt
#$webhookURL = "https://discord.com/api/webhooks/1163881495958663249/Ne_on6tWF1pJEfYX9-rG-tCj4l9rWqSO8b2ussiaxGCvzOLNDvQcHGjGgZT7Znn2UKqO"

$winnerMessage = Get-Content .\MMR\DailyWinner\winner_$date.txt
$loserMessage = Get-Content .\MMR\DailyLoser\bigLoser_$date.txt
$leaderboard = Import-Csv -Path .\SQLOutput\AllParticipants.csv

# Create embed array
[System.Collections.ArrayList]$embedArray = @()

# Store embed values
$title       = "Ladder Leaderboard for $prettyday"
$description = $winnerMessage + " " + $loserMessage + " To join the Discord, please visit here: https://discord.gg/VJQCveXcPw"

# Format the CSV data as a table in a code block
$csvDescription = '`' + ($leaderboard | Format-Table | Out-String)+'`'

# Create thumbnail object
$thumbUrl = 'https://i.imgur.com/XPghlWq.png'
$thumbnailObject = [PSCustomObject]@{
    url = $thumbUrl
}

$footerObject = [PSCustomObject]@{
    text = $day + " --- This bot is maintained by Galeforce. Values are pulled from last 25 games."
}

# Create embed object, also adding thumbnail
$embedObject = [PSCustomObject]@{

    title       = $title
    description = $description
    color       = '15780864'
    thumbnail   = $thumbnailObject
    footer      = $footerObject
}

# Add embed object to array
$embedArray.Add($embedObject) | Out-Null

# Create the payload
$payload = [PSCustomObject]@{

    content = $csvDescription
    embeds = $embedArray

}

try {
    # Send over payload, converting it to JSON
    Invoke-RestMethod -Uri $webhookURL -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'    
}
catch {
    $splitNumber = ($leaderboard.player.Count / 2)

    # Split the array into two arrays
    $array1 = $leaderboard[0..($splitNumber - 1)]
    $array2 = $leaderboard[$splitNumber..($leaderboard.Length - 1)]
    $leaderboard1 = $array1 + '`' + ($leaderboard | Format-Table | Out-String)+'`'
    $leaderboard2 = $array2 + '`' + ($leaderboard | Format-Table | Out-String)+'`'

    $payload1 = [PSCustomObject]@{

        content = $leaderboard1
        embeds = $embedArray
    
    }
    $payload2 = [PSCustomObject]@{

        content = $leaderboard2
        embeds = $embedArray
    
    }

    Invoke-RestMethod -Uri $webhookURL -Body ($payload1 | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json' 
    Invoke-RestMethod -Uri $webhookURL -Body ($payload2 | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'
}