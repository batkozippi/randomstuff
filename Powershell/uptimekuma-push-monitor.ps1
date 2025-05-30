# Uptime Kuma Ping Monitor Script
# Pings 8.8.8.8 and reports status to Uptime Kuma

# Configuration
$pingTarget = "8.8.8.8"
$uptimeKumaBaseUrl = ""
$pingCount = 4  # Number of ping attempts

try {
    Write-Host "Starting ping test to $pingTarget..." -ForegroundColor Yellow
    
    # Perform ping test
    $pingResult = Test-Connection -ComputerName $pingTarget -Count $pingCount -ErrorAction Stop
    
    # Calculate average response time
    $avgResponseTime = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
    $roundedPing = [math]::Round($avgResponseTime, 2)
    
    # Construct success URL
    $successUrl = "$uptimeKumaBaseUrl" + "?status=up&msg=OK&ping=$roundedPing"
    
    Write-Host "Ping successful! Average response time: $roundedPing ms" -ForegroundColor Green
    
    # Send success notification to Uptime Kuma
    $response = Invoke-WebRequest -Uri $successUrl -Method GET -TimeoutSec 10
    
    if ($response.StatusCode -eq 200) {
        Write-Host "Successfully reported UP status to Uptime Kuma" -ForegroundColor Green
    } else {
        Write-Host "Warning: Unexpected response from Uptime Kuma (Status: $($response.StatusCode))" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Ping failed: $($_.Exception.Message)" -ForegroundColor Red
    
    # Construct failure URL
    $failureUrl = "$uptimeKumaBaseUrl" + "?status=down&msg=Ping Failed: $($_.Exception.Message)"
    
    try {
        # Send failure notification to Uptime Kuma
        $response = Invoke-WebRequest -Uri $failureUrl -Method GET -TimeoutSec 10
        
        if ($response.StatusCode -eq 200) {
            Write-Host "Successfully reported DOWN status to Uptime Kuma" -ForegroundColor Red
        } else {
            Write-Host "Error: Could not report status to Uptime Kuma (Status: $($response.StatusCode))" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error: Failed to send notification to Uptime Kuma: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Monitoring check completed at $(Get-Date)" -ForegroundColor Cyan