$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$stdout=Join-Path $root '.codex_tmp\pre_DCM_watcher_stdout.log';$stderr=Join-Path $root '.codex_tmp\pre_DCM_watcher_stderr.log'
$script=Join-Path $root 'wait_and_finalize_pre_DCM_gate_V371.ps1'
$p=Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$script+'"') `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
@{process_id=$p.Id;started=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $root '.codex_tmp\pre_DCM_watcher_process.json')
Write-Output "Auto-finalizer watcher started under PID $($p.Id)."
