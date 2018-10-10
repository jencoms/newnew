$startTime = (get-date)
$symbols = (Invoke-RestMethod -Uri "https://api.iextrading.com/1.0/ref-data/symbols" -Method get | ?{ $_.isEnabled -eq "True" }).symbol
$threads = 6

for ($thread = 0; $thread -lt $threads; $thread++)
{
    Start-Job -ArgumentList $symbols, $thread, $threads -ScriptBlock {
        $startIndex = ([int]$args[0].count / [int]$args[2]) * [int]$args[1]

        $IndexEnd = $startIndex + (([int]$args[0].count / [int]$args[2]) - 1)

        $symbolsInThisBatch = New-Object System.Collections.ArrayList
        for ($i = $startIndex; $i -le $IndexEnd; $i++)
        {
            $symbolsInThisBatch.Add($args[0][$i]) | Out-Null

            if ($symbolsInThisBatch.count -eq 10 -or $i -eq $IndexEnd)
            {
                $temp = [string]$symbolsInThisBatch -join ','
                $querySymbols = $temp.Replace(' ', ',')
                Invoke-RestMethod -Uri "https://api.iextrading.com/1.0/stock/market/batch?symbols=$querySymbols&types=quote&range=1m&last=10" -Method Get
                $symbolsInThisBatch.Clear()
            }
        }
    }
}

$isRunning = $true

while ($isRunning)
{
    #Write-Host "Jobs are still running..."
    $shouldTerminate = $true
    $jobs = Get-Job

    foreach ($job in $jobs)
    {
        if ($job.state -ne "Completed")
        {
            $shouldTerminate = $false
        }
    }

    $isRunning = !$shouldTerminate
    start-sleep -Seconds 1
}

Write-Host "jobs complete!" -ForegroundColor Green
Write-Host "time to complete: $( $endTime - $startTime )"

$fileDate = (get-date).ToString("yyyy-MM-dd_HH-mm")
$fileName = "allStocks_$fileDate" + ".json"
$data = Get-Job | Receive-Job -Keep -ErrorAction SilentlyContinue

#Write-Host "$data"

$formattedData = foreach ($object in $data)
{
    $dataSymbols = $object | Get-Member -MemberType Properties | select -ExpandProperty Name
    foreach ($entry in $dataSymbols)
    {
        try
        {
            Invoke-Expression '$object | select -expandproperty $entry | select -expandproperty quote -erroraction silentlycontinue'
        }
        catch
        {
        }
    }
}

$nl = [Environment]::NewLine
$InsertStm = @()

foreach ($tickData in $formattedData)
{
    $InsertStm += "INSERT INTO [dbo].[stockwatcher] ('" + $tickData.symbol + "','" + $tickData.companyname + "')" + $nl
}


Write-Host $InsertStm




Get-Job | Remove-Job
