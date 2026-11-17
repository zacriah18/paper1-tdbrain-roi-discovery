$ErrorActionPreference='Stop'
$pipeline='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V37_1_covariate_conditioned_discovery'
$derivatives='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$logdir=Join-Path $derivatives 'logs';New-Item -ItemType Directory -Force -Path $logdir|Out-Null
$pidfile=Join-Path $logdir 'V371_sensor.pid'
if(Test-Path -LiteralPath $pidfile){$old=[int](Get-Content -LiteralPath $pidfile);if(Get-Process -Id $old -ErrorAction SilentlyContinue){Write-Output "V37.1 sensor job already active under PID $old.";exit 0}}
$driver=Join-Path $pipeline 'run_V371_sensor_comparator.m';$expr="run('$($driver -replace "'","''")')"
$stdout=Join-Path $logdir 'V371_sensor_stdout.log';$stderr=Join-Path $logdir 'V371_sensor_stderr.log'
$p=Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' -ArgumentList '-batch',('"'+$expr+'"') `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try{$p.PriorityClass='BelowNormal'}catch{};$p.Id|Set-Content -LiteralPath $pidfile
Write-Output "Started V37.1 sensor comparator PID $($p.Id)."
