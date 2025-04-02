# Configuration
$pingTarget = "1.1.1.1"
$webhookUrl = ""
$maxRetries = 5
$retryDelaySeconds = 5
$logFile = "C:\temp\PingMonitor.log"

# Ensure log directory exists
$logDir = Split-Path $logFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Run the ping (4 attempts)
$pingResult = Test-Connection -ComputerName $pingTarget -Count 5 -ErrorAction SilentlyContinue

# If no response
if (-not $pingResult) {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Output "[$timestamp] Ping failed. Attempting to send notification..."

    # Prepare webhook message
    $body = @{
        message = "Ping to $pingTarget failed at $timestamp"
    } | ConvertTo-Json

    $attempt = 1
    $success = $false

    while ($attempt -le $maxRetries -and -not $success) {
        try {
            Invoke-WebRequest -Uri $webhookUrl -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 10
            $logEntry = "[$timestamp] Ping to $pingTarget failed. Webhook sent successfully on attempt $attempt."
            $success = $true
        } catch {
            $logEntry = "[$timestamp] Ping to $pingTarget failed. Webhook attempt $attempt failed: $_"
            if ($attempt -lt $maxRetries) {
                Start-Sleep -Seconds $retryDelaySeconds
            }
            $attempt++
        }
        Add-Content -Path $logFile -Value $logEntry
    }

    if (-not $success) {
        $finalFail = "[$timestamp] All $maxRetries webhook attempts failed."
        Add-Content -Path $logFile -Value $finalFail
        Write-Error $finalFail
    }
}
else {
    Write-Output "Ping successful."
}
