param([switch]$Smoke)
$derivatives='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$tag=if($Smoke){'smoke'}else{'full'}
$folder=if($Smoke){'05_peer_set_comparison_smoke'}else{'05_peer_set_comparison'}
$logdir=Join-Path $derivatives 'logs';$pidfile=Join-Path $logdir "V371_peer_set_$tag.pid"
$stdout=Join-Path $logdir "V371_peer_set_${tag}_stdout.log";$stderr=Join-Path $logdir "V371_peer_set_${tag}_stderr.log"
$result=Join-Path $derivatives "$folder\A08_peer_set_comparison.mat"
$manifest=Join-Path $derivatives "$folder\A08_validation_freeze_manifest.json"
Write-Host "V37.1 peer-set $tag status at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$process=$null
if(Test-Path -LiteralPath $pidfile){$id=[int](Get-Content -LiteralPath $pidfile);$process=Get-Process -Id $id -ErrorAction SilentlyContinue}
if($process){[pscustomobject]@{Id=$process.Id;Start=$process.StartTime;CPU_s=[math]::Round($process.CPU,1);Priority=$process.PriorityClass}|Format-Table -AutoSize|Out-String|Write-Host}else{Write-Host 'No active peer-set process found.'}
$lines=@();if(Test-Path -LiteralPath $stdout){$lines=@(Get-Content -LiteralPath $stdout)}
$fold=@($lines|Where-Object{$_ -match '^peer repeat\s+\d+\s+fold\s+\d+:'})
$sensitivity=@($lines|Where-Object{$_ -match '^peer sensitivity repeat\s+\d+\s+fold\s+\d+:'})
$target=if($Smoke){5}else{25}
Write-Host "Candidate-construction folds: $($fold.Count)/$target"
if($fold.Count -gt 0){Write-Host "Latest: $($fold[-1])"}
Write-Host "Sensitivity folds: $($sensitivity.Count)/$target"
if($sensitivity.Count -gt 0){Write-Host "Latest: $($sensitivity[-1])"}
Write-Host "Final result: $(Test-Path -LiteralPath $result)"
Write-Host "Validation freeze manifest: $(Test-Path -LiteralPath $manifest)"
if(Test-Path -LiteralPath $stdout){$info=Get-Item -LiteralPath $stdout;Write-Host "Log updated: $($info.LastWriteTime)"}
if((Test-Path -LiteralPath $stderr)-and(Get-Item -LiteralPath $stderr).Length -gt 0){Write-Host 'Recent stderr';Get-Content -LiteralPath $stderr -Tail 16|Write-Host}
