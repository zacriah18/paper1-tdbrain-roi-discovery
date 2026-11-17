$derivative='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$logs=Join-Path $derivative 'logs\robustness_sensitivities'
$manifest=Join-Path $logs 'sensitivity_pids.csv'
Write-Host "V37.1 robustness status at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if(!(Test-Path $manifest)){Write-Host 'No robustness sensitivity manifest found.'; exit 0}
foreach($row in (Import-Csv -LiteralPath $manifest)){
    $p=Get-Process -Id ([int]$row.pid) -ErrorAction SilentlyContinue
    $out=Join-Path $derivative ("08_robustness_sensitivities\{0}\A18_sensitivity_summary.csv" -f $row.sensitivity)
    $latest=''
    if(Test-Path $row.stdout){$latest=(Get-Content -LiteralPath $row.stdout -Tail 1)}
    [pscustomobject]@{
        Sensitivity=$row.sensitivity
        PID=$row.pid
        Running=[bool]$p
        CPU_s=if($p){[math]::Round($p.CPU,1)}else{$null}
        Complete=(Test-Path $out)
        Latest=$latest
    } | Format-List | Out-String | Write-Host
    if((Test-Path $row.stderr) -and (Get-Item -LiteralPath $row.stderr).Length -gt 0){
        Write-Host 'stderr:'; Get-Content -LiteralPath $row.stderr -Tail 8 | Write-Host
    }
}
