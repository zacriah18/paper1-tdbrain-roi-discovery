$ErrorActionPreference='Stop'
$pipeline='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V37_1_covariate_conditioned_discovery'
$derivatives='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$logdir=Join-Path $derivatives 'logs';New-Item -ItemType Directory -Force -Path $logdir|Out-Null
$pidfile=Join-Path $logdir 'V371_validation.pid'
if(Test-Path -LiteralPath $pidfile){$existing=[int](Get-Content -LiteralPath $pidfile);if(Get-Process -Id $existing -ErrorAction SilentlyContinue){Write-Output "Validation is already active under PID $existing.";exit 0}}
$driver=Join-Path $pipeline 'run_validation_V371.m';$expr="run('$($driver -replace "'","''")')"
$stdout=Join-Path $logdir 'V371_validation_stdout.log';$stderr=Join-Path $logdir 'V371_validation_stderr.log'
$process=Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' -ArgumentList '-batch',('"'+$expr+'"') `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try{$process.PriorityClass='BelowNormal'}catch{};$process.Id|Set-Content -LiteralPath $pidfile
Write-Output "Started frozen V37.1 validation under PID $($process.Id)."
