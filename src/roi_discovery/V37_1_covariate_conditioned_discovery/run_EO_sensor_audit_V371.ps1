$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$logRoot=Join-Path $root '.codex_tmp';New-Item -ItemType Directory -Force -Path $logRoot|Out-Null
$stdout=Join-Path $logRoot 'EO_sensor_audit_stdout.log';$stderr=Join-Path $logRoot 'EO_sensor_audit_stderr.log'
$driver=Join-Path $root 'run_EO_sensor_audit_V371.m';$expr="run('$($driver -replace "'","''")')"
$p=Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' -ArgumentList '-batch',('"'+$expr+'"') `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
try{$p.PriorityClass='BelowNormal'}catch{}
@{process_id=$p.Id;started=(Get-Date).ToString('o');stdout=$stdout;stderr=$stderr}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $logRoot 'EO_sensor_audit_process.json')
Write-Output "Started EO sensor audit under PID $($p.Id)."
