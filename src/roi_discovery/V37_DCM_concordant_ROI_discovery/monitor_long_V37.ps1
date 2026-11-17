$derivatives = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_DCM_concordant_ROI_discovery'
$statusFile = Join-Path $derivatives '02_node_features\A02_node_feature_extraction_status.csv'
$pidfile = Join-Path $derivatives 'logs\V37_long_run.pid'
$stdout = Join-Path $derivatives 'logs\V37_long_stdout.log'
$stderr = Join-Path $derivatives 'logs\V37_long_stderr.log'
$primarySummary = Join-Path $derivatives '04_supervised_discovery\A04_discovery_performance_summary.csv'
$pairedSummary = Join-Path $derivatives '04_supervised_discovery\A04c_paired_EC_EO_summary.csv'
$shortlist = Join-Path $derivatives '05_shortlist\A05_frozen_spatial_shortlist.csv'

Write-Host "V37 status at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ''
Write-Host 'Processes'
$wrapper = $null
if (Test-Path -LiteralPath $pidfile) {
    $wrapperId = [int](Get-Content -LiteralPath $pidfile)
    $wrapper = Get-Process -Id $wrapperId -ErrorAction SilentlyContinue
}
$workers = @(Get-Process -Name MATLAB -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Path -like '*\bin\win64\MATLAB.exe' -and
        $wrapper -and $_.StartTime -ge $wrapper.StartTime.AddSeconds(-5) -and
        $_.StartTime -le $wrapper.StartTime.AddMinutes(1)
    })
$processRows = @()
if ($wrapper) {
    $processRows += [pscustomobject]@{Role='launcher'; Id=$wrapper.Id; State='running'; Start=$wrapper.StartTime; CPU_s=[math]::Round($wrapper.CPU,1); Priority=$wrapper.PriorityClass}
}
foreach ($worker in $workers) {
    $processRows += [pscustomobject]@{Role='worker'; Id=$worker.Id; State='running'; Start=$worker.StartTime; CPU_s=[math]::Round($worker.CPU,1); Priority=$worker.PriorityClass}
}
if ($processRows.Count -gt 0) {
    $processRows | Format-Table -AutoSize | Out-String | Write-Host
} else {
    Write-Host 'No active V37 process found.'
}

Write-Host 'Recording features'
if (Test-Path -LiteralPath $statusFile) {
    $status = Import-Csv -LiteralPath $statusFile
    $ok = @($status | Where-Object { $_.status -in @('OK','SKIPPED_EXISTS') }).Count
    $errors = @($status | Where-Object status -eq 'ERROR').Count
    $pending = @($status | Where-Object status -eq 'PENDING').Count
    Write-Host "$ok/$($status.Count) complete; $errors errors; $pending pending"
} else {
    Write-Host 'Not started.'
}

$lines = @()
if (Test-Path -LiteralPath $stdout) { $lines = @(Get-Content -LiteralPath $stdout) }
$foldLines = @($lines | Where-Object { $_ -match '^repeat\s+\d+\s+fold\s+\d+:' })
Write-Host ''
Write-Host 'Analysis stage'
if (-not (Test-Path -LiteralPath $primarySummary)) {
    Write-Host "PRIMARY nested CV: $($foldLines.Count)/25 outer folds complete"
} elseif (-not (Test-Path -LiteralPath $pairedSummary)) {
    $pairedFolds = [math]::Max(0,$foldLines.Count-25)
    Write-Host "Primary nested CV complete; PAIRED EC-EO nested CV: $pairedFolds/25 folds complete"
} elseif (-not (Test-Path -LiteralPath $shortlist)) {
    Write-Host 'Primary and paired analyses complete; freezing spatial shortlist.'
} else {
    Write-Host 'PRIMARY PIPELINE COMPLETE: spatial shortlist is available.'
}
if ($foldLines.Count -gt 0) { Write-Host "Latest fold: $($foldLines[-1])" }
if (Test-Path -LiteralPath $stdout) {
    $logInfo = Get-Item -LiteralPath $stdout
    $age = [math]::Round(((Get-Date)-$logInfo.LastWriteTime).TotalMinutes,1)
    Write-Host "Log updated: $($logInfo.LastWriteTime) ($age minutes ago)"
}

Write-Host ''
Write-Host 'Completion files'
Write-Host "Primary summary: $(Test-Path -LiteralPath $primarySummary)"
Write-Host "Paired summary:  $(Test-Path -LiteralPath $pairedSummary)"
Write-Host "ROI shortlist:   $(Test-Path -LiteralPath $shortlist)"
if ((Test-Path -LiteralPath $stderr) -and (Get-Item -LiteralPath $stderr).Length -gt 0) {
    Write-Host ''
    Write-Host 'Recent stderr'
    Get-Content -LiteralPath $stderr -Tail 10 | Write-Host
}
