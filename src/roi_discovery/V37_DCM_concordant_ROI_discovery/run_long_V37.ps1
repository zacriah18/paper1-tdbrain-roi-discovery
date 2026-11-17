param([switch]$StartRelationshipScreen)
$ErrorActionPreference = 'Stop'
$pipeline = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V37_DCM_concordant_ROI_discovery'
$derivatives = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_DCM_concordant_ROI_discovery'
$logdir = Join-Path $derivatives 'logs'
New-Item -ItemType Directory -Force -Path $logdir | Out-Null
$pidfile = Join-Path $logdir 'V37_long_run.pid'
if (Test-Path -LiteralPath $pidfile) {
    $existingPid = [int](Get-Content -LiteralPath $pidfile)
    if (Get-Process -Id $existingPid -ErrorAction SilentlyContinue) {
        Write-Output "V37 is already running under wrapper PID $existingPid."
        exit 0
    }
}
Remove-Item Env:TDBRAIN_V37_MAX_RECORDINGS -ErrorAction SilentlyContinue
Remove-Item Env:TDBRAIN_V37_OUTER_REPEATS -ErrorAction SilentlyContinue
Remove-Item Env:TDBRAIN_V37_PERMUTATIONS -ErrorAction SilentlyContinue

$driver = Join-Path $pipeline 'run_V37_primary_pipeline.m'
$expr = "run('$($driver -replace "'","''")')"
if ($StartRelationshipScreen) {
    $edge = Join-Path $pipeline '06_relationship_screen\A06_extract_shortlist_directed_dependence_V37.m'
    $expr += "; run('$($edge -replace "'","''")')"
}
$stdout = Join-Path $logdir 'V37_long_stdout.log'
$stderr = Join-Path $logdir 'V37_long_stderr.log'
$process = Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' `
    -ArgumentList '-batch',('"' + $expr + '"') -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try { $process.PriorityClass = 'BelowNormal' } catch { }
$process.Id | Set-Content -LiteralPath $pidfile
Write-Output "Started V37 MATLAB wrapper PID $($process.Id)."
Write-Output "Stdout: $stdout"
Write-Output "Relationship screen requested: $StartRelationshipScreen"
