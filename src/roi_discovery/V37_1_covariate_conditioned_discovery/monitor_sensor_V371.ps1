$d='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$status=Join-Path $d '04_sensor_comparator\A04_sensor_extraction_status.csv'
$result=Join-Path $d '04_sensor_comparator\A06_sensor_model_performance.csv'
$pidfile=Join-Path $d 'logs\V371_sensor.pid';$stdout=Join-Path $d 'logs\V371_sensor_stdout.log';$stderr=Join-Path $d 'logs\V371_sensor_stderr.log'
Write-Host "V37.1 sensor status at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if(Test-Path $pidfile){$id=[int](Get-Content $pidfile);$p=Get-Process -Id $id -ErrorAction SilentlyContinue;if($p){$p|Select-Object Id,StartTime,CPU,PriorityClass|Format-Table -AutoSize|Out-String|Write-Host}else{Write-Host 'No active sensor wrapper.'}}
if(Test-Path $status){$s=Import-Csv $status;$ok=@($s|Where-Object status -in @('OK','SKIPPED_EXISTS')).Count;$err=@($s|Where-Object status -eq 'ERROR').Count;Write-Host "Recordings: $ok/$($s.Count) complete; $err errors."}else{Write-Host 'Extraction status not yet written.'}
Write-Host "Comparator complete: $(Test-Path $result)";if(Test-Path $result){Import-Csv $result|Format-Table -AutoSize|Out-String|Write-Host}
if(Test-Path $stdout){$i=Get-Item $stdout;Write-Host "Log updated: $($i.LastWriteTime)";Get-Content $stdout -Tail 3|Write-Host}
if((Test-Path $stderr)-and(Get-Item $stderr).Length-gt 0){Write-Host 'Recent stderr';Get-Content $stderr -Tail 10|Write-Host}
