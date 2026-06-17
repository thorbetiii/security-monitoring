$baseUrl = "http://localhost:8080"
$durationMinutes = 45
$endTime = (Get-Date).AddMinutes($durationMinutes)

$requestCount = 0
$failedCount = 0

while ((Get-Date) -lt $endTime) {
    $paths = @(
        "/",
        "/product/OLJCESPC7Z",
        "/cart"
    )

    foreach ($path in $paths) {
        try {
            curl.exe `
              -s `
              --max-time 10 `
              -o NUL `
              "$baseUrl$path"

            $requestCount++
        }
        catch {
            $failedCount++
        }

        Start-Sleep -Seconds 2
    }
}

@"
Baseline completed: $(Get-Date -Format o)
Successful requests: $requestCount
Failed requests: $failedCount
"@ | Out-File ".\evidence\02-formal-baseline\traffic-summary.txt"