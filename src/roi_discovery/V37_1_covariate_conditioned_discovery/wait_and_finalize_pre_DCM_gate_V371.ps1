$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$tmp=Join-Path $root '.codex_tmp';$state=Join-Path $tmp 'pre_DCM_gate_process.json'
if(!(Test-Path -LiteralPath $state)){throw 'The CSD gate process state file is missing.'}
$j=Get-Content -LiteralPath $state|ConvertFrom-Json
$p=Get-Process -Id ([int]$j.process_id) -ErrorAction SilentlyContinue
if($p){$p|Wait-Process}
$driver=Join-Path $root 'run_finalize_pre_DCM_gate_V371.m';$expr="run('$($driver -replace "'","''")')"
$stdout=Join-Path $tmp 'pre_DCM_finalize_stdout.log';$stderr=Join-Path $tmp 'pre_DCM_finalize_stderr.log'
$final=Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' -ArgumentList '-batch',('"'+$expr+'"') `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
try{$final.PriorityClass='BelowNormal'}catch{}
@{process_id=$final.Id;started=(Get-Date).ToString('o');stdout=$stdout;stderr=$stderr}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $tmp 'pre_DCM_finalize_process.json')
$final|Wait-Process
