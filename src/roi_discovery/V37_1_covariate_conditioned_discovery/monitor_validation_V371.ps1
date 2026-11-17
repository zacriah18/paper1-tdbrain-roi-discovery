$derivatives='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$out=Join-Path $derivatives '06_heldout_validation';$logdir=Join-Path $derivatives 'logs';$pidfile=Join-Path $logdir 'V371_validation.pid'
$stdout=Join-Path $logdir 'V371_validation_stdout.log';$stderr=Join-Path $logdir 'V371_validation_stderr.log'
Write-Host "V37.1 frozen validation status at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$process=$null;if(Test-Path -LiteralPath $pidfile){$id=[int](Get-Content -LiteralPath $pidfile);$process=Get-Process -Id $id -ErrorAction SilentlyContinue}
if($process){[pscustomobject]@{Id=$process.Id;Start=$process.StartTime;CPU_s=[math]::Round($process.CPU,1);Priority=$process.PriorityClass}|Format-Table -AutoSize|Out-String|Write-Host}else{Write-Host 'No active validation process found.'}
$lines=@();if(Test-Path -LiteralPath $stdout){$lines=@(Get-Content -LiteralPath $stdout)}
$extract=@($lines|Where-Object{$_ -match '^validation extraction\s+\d+/186'})
Write-Host "Validation recordings extracted: $($extract.Count)/186";if($extract.Count -gt 0){Write-Host "Latest: $($extract[-1])"}
Write-Host "Participant features assembled: $(Test-Path -LiteralPath (Join-Path $out 'A10_validation_participant_spectral_landscapes.mat'))"
Write-Host "Frozen model scored: $(Test-Path -LiteralPath (Join-Path $out 'A11_frozen_validation_results.mat'))"
if(Test-Path -LiteralPath $stdout){$info=Get-Item -LiteralPath $stdout;Write-Host "Log updated: $($info.LastWriteTime)"}
if((Test-Path -LiteralPath $stderr)-and(Get-Item -LiteralPath $stderr).Length -gt 0){Write-Host 'Recent stderr';Get-Content -LiteralPath $stderr -Tail 16|Write-Host}
