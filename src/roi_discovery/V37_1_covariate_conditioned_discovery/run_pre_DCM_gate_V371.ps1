$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$logRoot = Join-Path $root '.codex_tmp'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$stdout = Join-Path $logRoot 'pre_DCM_gate_stdout.log'
$stderr = Join-Path $logRoot 'pre_DCM_gate_stderr.log'
$matlab = 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe'
$cmd = "cd('$($root.Replace("'","''"))'); run('run_pre_DCM_gate_V371.m');"
$p = Start-Process -FilePath $matlab -ArgumentList '-batch',('"'+$cmd+'"') -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
try { $p.PriorityClass = 'BelowNormal' } catch { }
@{
    process_id = $p.Id
    started = (Get-Date).ToString('o')
    stdout = $stdout
    stderr = $stderr
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logRoot 'pre_DCM_gate_process.json')
Write-Output "Started V37.1 pre-DCM gate under PID $($p.Id)."
Write-Output "Stdout: $stdout"
