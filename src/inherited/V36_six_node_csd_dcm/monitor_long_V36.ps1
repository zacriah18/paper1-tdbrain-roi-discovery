$outputRoot = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V36_six_node_csd_dcm\02_first_level'
$pidFile = Join-Path $outputRoot 'V36_long_run.pid'
$statusFile = Join-Path $outputRoot 'A02_first_level_run_status.csv'
$stdout = Join-Path $outputRoot 'V36_long_run_stdout.log'
$pidValue = if (Test-Path -LiteralPath $pidFile) { [int](Get-Content -LiteralPath $pidFile -Raw) } else { 0 }
$running = if ($pidValue) { [bool](Get-Process -Id $pidValue -ErrorAction SilentlyContinue) } else { $false }
$summary = @()
$completed = 0
$errors = 0
$active = 0
$total = 0
if (Test-Path -LiteralPath $statusFile) {
    $rows = Import-Csv -LiteralPath $statusFile
    $total = $rows.Count
    $completed = @($rows | Where-Object { $_.status -in @('OK','OK_EXISTING') }).Count
    $errors = @($rows | Where-Object { $_.status -eq 'ERROR' }).Count
    $active = @($rows | Where-Object { $_.status -eq 'RUNNING' }).Count
    $summary = $rows | Group-Object status | Select-Object Name,Count
}
[pscustomobject]@{ PID=$pidValue; Running=$running; Total=$total; Completed=$completed; Errors=$errors; Active=$active; PercentComplete=if($total){[math]::Round(100*$completed/$total,2)}else{0} }
$summary | Format-Table -AutoSize
if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Tail 20 }
