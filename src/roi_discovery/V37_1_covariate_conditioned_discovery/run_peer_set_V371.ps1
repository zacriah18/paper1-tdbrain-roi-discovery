param([switch]$Smoke)
$ErrorActionPreference='Stop'
$pipeline='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V37_1_covariate_conditioned_discovery'
$derivatives='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$logdir=Join-Path $derivatives 'logs';New-Item -ItemType Directory -Force -Path $logdir|Out-Null
$tag=if($Smoke){'smoke'}else{'full'}
$pidfile=Join-Path $logdir "V371_peer_set_$tag.pid"
if(Test-Path -LiteralPath $pidfile){
    $existing=[int](Get-Content -LiteralPath $pidfile)
    if(Get-Process -Id $existing -ErrorAction SilentlyContinue){Write-Output "Peer-set run is already active under PID $existing.";exit 0}
}
if($Smoke){$env:TDBRAIN_V371_PEER_SMOKE='true'}else{Remove-Item Env:TDBRAIN_V371_PEER_SMOKE -ErrorAction SilentlyContinue}
$driver=Join-Path $pipeline 'run_V371_peer_set_comparison.m'
$expr="run('$($driver -replace "'","''")')"
$stdout=Join-Path $logdir "V371_peer_set_${tag}_stdout.log"
$stderr=Join-Path $logdir "V371_peer_set_${tag}_stderr.log"
$process=Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' `
    -ArgumentList '-batch',('"'+$expr+'"') -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try{$process.PriorityClass='BelowNormal'}catch{}
$process.Id|Set-Content -LiteralPath $pidfile
Write-Output "Started V37.1 peer-set $tag run under PID $($process.Id)."
Write-Output "Stdout: $stdout"
