$derivatives = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$pidfile = Join-Path $derivatives 'logs\V371_long_run.pid'
$stdout = Join-Path $derivatives 'logs\V371_long_stdout.log'
$stderr = Join-Path $derivatives 'logs\V371_long_stderr.log'
$observed = Join-Path $derivatives '02_conditioned_models\A02_model_performance.csv'
$increment = Join-Path $derivatives '02_conditioned_models\A02_primary_incremental_performance.csv'
$permutation = Join-Path $derivatives '03_permutation\A03_conditional_permutation_summary.csv'
$checkpoint = Join-Path $derivatives '03_permutation\A03_conditional_full_pipeline_permutations.mat'

Write-Host "V37.1 status at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$wrapper = $null
if (Test-Path -LiteralPath $pidfile) {
    $wrapperId = [int](Get-Content -LiteralPath $pidfile)
    $wrapper = Get-Process -Id $wrapperId -ErrorAction SilentlyContinue
}
if ($wrapper) {
    [pscustomobject]@{Role='launcher';Id=$wrapper.Id;Start=$wrapper.StartTime;CPU_s=[math]::Round($wrapper.CPU,1);Priority=$wrapper.PriorityClass} |
        Format-Table -AutoSize | Out-String | Write-Host
} else { Write-Host 'No active V37.1 wrapper found.' }

$lines = @(); if (Test-Path -LiteralPath $stdout) { $lines = @(Get-Content -LiteralPath $stdout) }
$foldLines = @($lines | Where-Object { $_ -match '^repeat\s+\d+\s+fold\s+\d+:' })
$permLines = @($lines | Where-Object { $_ -match '^conditional permutation\s+\d+/' })
$observedDoneIndex = -1
for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^V37\.1 OBSERVED ANALYSIS COMPLETE') { $observedDoneIndex=$i; break }
}
if ($observedDoneIndex -ge 0) {
    $observedFoldLines = @($lines[0..$observedDoneIndex] | Where-Object { $_ -match '^repeat\s+\d+\s+fold\s+\d+:' })
    $postObserved = @(); if ($observedDoneIndex+1 -lt $lines.Count) { $postObserved=@($lines[($observedDoneIndex+1)..($lines.Count-1)]) }
    $permutationFoldLines = @($postObserved | Where-Object { $_ -match '^repeat\s+\d+\s+fold\s+\d+:' })
    Write-Host "Observed outer folds logged: $($observedFoldLines.Count)/25 (complete)"
    $currentPermutationFolds = $permutationFoldLines.Count - 25*$permLines.Count
    if ($currentPermutationFolds -gt 0) {
        Write-Host "Current conditional permutation: $($permLines.Count+1); outer folds $currentPermutationFolds/25"
        Write-Host "Latest permutation fold: $($permutationFoldLines[-1])"
    }
} else {
    Write-Host "Observed outer folds logged: $([math]::Min($foldLines.Count,25))/25"
    if ($foldLines.Count -gt 0) { Write-Host "Latest observed fold: $($foldLines[-1])" }
}
Write-Host "Observed result available: $(Test-Path -LiteralPath $observed)"
if (Test-Path -LiteralPath $increment) { Import-Csv $increment | Format-Table -AutoSize | Out-String | Write-Host }
Write-Host "Conditional permutations logged this run: $($permLines.Count)"
if ($permLines.Count -gt 0) { Write-Host "Latest permutation: $($permLines[-1])" }
Write-Host "Permutation checkpoint: $(Test-Path -LiteralPath $checkpoint)"
Write-Host "Permutation summary: $(Test-Path -LiteralPath $permutation)"
if (Test-Path -LiteralPath $stdout) {
    $info = Get-Item -LiteralPath $stdout
    Write-Host "Log updated: $($info.LastWriteTime)"
}
if ((Test-Path -LiteralPath $stderr) -and (Get-Item -LiteralPath $stderr).Length -gt 0) {
    Write-Host 'Recent stderr'; Get-Content -LiteralPath $stderr -Tail 12 | Write-Host
}
