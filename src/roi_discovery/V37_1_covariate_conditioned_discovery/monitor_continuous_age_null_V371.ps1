$derivative='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$out=Join-Path $derivative '08_robustness_sensitivities\continuous_age_parametric_null'
$logs=Join-Path $derivative 'logs\continuous_age_parametric_null'
$manifest=Join-Path $logs 'worker_pids.csv'
$shards=Join-Path $out 'shards'
$files=@(); if(Test-Path $shards){$files=@(Get-ChildItem -LiteralPath $shards -Filter 'bootstrap_*.mat')}
Write-Host "V37.1 continuous-age null status at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Completed bootstraps: $($files.Count)/1000"
if(Test-Path $manifest){
    foreach($row in (Import-Csv -LiteralPath $manifest)){
        $p=Get-Process -Id ([int]$row.pid) -ErrorAction SilentlyContinue
        $latest=''; if(Test-Path $row.stdout){$latest=Get-Content -LiteralPath $row.stdout -Tail 1}
        [pscustomobject]@{Worker=$row.worker;PID=$row.pid;Running=[bool]$p;CPU_s=if($p){[math]::Round($p.CPU,1)}else{$null};Latest=$latest} | Format-List | Out-String | Write-Host
        if((Test-Path $row.stderr) -and (Get-Item -LiteralPath $row.stderr).Length -gt 0){
            Write-Host 'stderr:'; Get-Content -LiteralPath $row.stderr -Tail 8 | Write-Host
        }
    }
}else{Write-Host 'No null worker manifest found.'}
Write-Host "Aggregate complete: $(Test-Path (Join-Path $out 'A19c_continuous_age_null_summary.csv'))"
$finalizerManifest=Join-Path $logs 'finalizer_pid.csv';$finalizerStatus=Join-Path $logs 'finalizer_status.csv'
if(Test-Path $finalizerManifest){$f=Import-Csv -LiteralPath $finalizerManifest|Select-Object -First 1;$fp=Get-Process -Id ([int]$f.pid) -ErrorAction SilentlyContinue;Write-Host "Finalizer PID $($f.pid); running=$([bool]$fp)"}
if(Test-Path $finalizerStatus){Import-Csv -LiteralPath $finalizerStatus|Format-List|Out-String|Write-Host}
