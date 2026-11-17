param([switch]$StartPermutation)
$ErrorActionPreference = 'Stop'
$pipeline = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V37_1_covariate_conditioned_discovery'
$derivatives = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$logdir = Join-Path $derivatives 'logs'
New-Item -ItemType Directory -Force -Path $logdir | Out-Null
$pidfile = Join-Path $logdir 'V371_long_run.pid'
if (Test-Path -LiteralPath $pidfile) {
    $existingPid = [int](Get-Content -LiteralPath $pidfile)
    if (Get-Process -Id $existingPid -ErrorAction SilentlyContinue) {
        Write-Output "V37.1 is already running under wrapper PID $existingPid."
        exit 0
    }
}
Remove-Item Env:TDBRAIN_V371_OUTER_REPEATS -ErrorAction SilentlyContinue
Remove-Item Env:TDBRAIN_V371_PERMUTATIONS -ErrorAction SilentlyContinue
$driver = Join-Path $pipeline 'run_V371_observed.m'
$expr = "run('$($driver -replace "'","''")')"
if ($StartPermutation) {
    $perm = Join-Path $pipeline '03_permutation\A03_run_conditional_full_pipeline_permutations_V371.m'
    $expr += "; run('$($perm -replace "'","''")')"
}
$stdout = Join-Path $logdir 'V371_long_stdout.log'
$stderr = Join-Path $logdir 'V371_long_stderr.log'
$process = Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' `
    -ArgumentList '-batch',('"' + $expr + '"') -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try { $process.PriorityClass = 'BelowNormal' } catch { }
$process.Id | Set-Content -LiteralPath $pidfile
Write-Output "Started V37.1 MATLAB wrapper PID $($process.Id)."
Write-Output "Stdout: $stdout"
Write-Output "Conditional permutation requested: $StartPermutation"
