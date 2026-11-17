$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery\07_pre_DCM_gate'
$state = Join-Path $root '.codex_tmp\pre_DCM_gate_process.json'
Write-Host "V37.1 pre-DCM gate at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if (Test-Path -LiteralPath $state) {
    $j = Get-Content -LiteralPath $state | ConvertFrom-Json
    $p = Get-Process -Id $j.process_id -ErrorAction SilentlyContinue
    if ($p) { Write-Host "MATLAB active: PID $($p.Id), CPU $([math]::Round($p.CPU,1)) s" } else { Write-Host 'No active MATLAB process.' }
}
$csv = Join-Path $out 'A16_CSD_observability_status.csv'
if (Test-Path -LiteralPath $csv) {
    $t = Import-Csv -LiteralPath $csv
    $done = @($t | Where-Object {$_.status -in @('OK','SKIPPED_EXISTS')}).Count
    $err = @($t | Where-Object {$_.status -eq 'ERROR'}).Count
    Write-Host "CSD observability: $done/$($t.Count) complete; $err errors"
    $last = $t | Where-Object {$_.status -ne 'PENDING'} | Select-Object -Last 1
    if ($last) { Write-Host "Latest: $($last.subject_id) $($last.condition) $($last.status) $($last.elapsed_seconds)s" }
}
$summary = Join-Path $out 'A16_CSD_observability_summary.csv'
Write-Host "Final summary available: $(Test-Path -LiteralPath $summary)"
