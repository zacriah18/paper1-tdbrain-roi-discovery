$source='C:\MATLAB\2026 TDBRAIN dataset'
$logRoot=Join-Path $source 'derivatives\V371_jump100_sensitivity_logs'
$manifest=Join-Path $logRoot 'coordinator.csv'
$status=Join-Path $logRoot 'phase_status.csv'
$dSummary=Join-Path $source 'derivatives\D_artifact_reject_shortlist_jump100_sensitivity\D_artifact_reject_shortlist_summary.csv'
$eStatus=Join-Path $source 'derivatives\E_source_reconstruction_shortlist_QC_jump100_sensitivity\E_source_reconstruction_status.csv'
Write-Host "V37.1 jump-100 preprocessing sensitivity at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if(Test-Path $manifest){
    $row=Import-Csv -LiteralPath $manifest | Select-Object -First 1
    $p=Get-Process -Id ([int]$row.pid) -ErrorAction SilentlyContinue
    Write-Host "Coordinator PID $($row.pid); running=$([bool]$p)"
}
if(Test-Path $status){Import-Csv -LiteralPath $status | Format-List | Out-String | Write-Host}else{Write-Host 'No phase status yet.'}
if(Test-Path $dSummary){
    $d=Import-Csv -LiteralPath $dSummary
    Write-Host "Stage D rows=$($d.Count); OK=$(@($d|Where-Object status -eq 'OK').Count); ERROR=$(@($d|Where-Object status -eq 'ERROR').Count)"
}
if(Test-Path $eStatus){
    $e=Import-Csv -LiteralPath $eStatus
    Write-Host "Stage E rows=$($e.Count); OK=$(@($e|Where-Object status -eq 'OK').Count); ERROR=$(@($e|Where-Object status -eq 'ERROR').Count)"
}
foreach($name in @('D','E','coordinator')){
    $err=Join-Path $logRoot ("${name}_stderr.log")
    if((Test-Path $err) -and (Get-Item -LiteralPath $err).Length -gt 0){Write-Host "$name stderr:";Get-Content -LiteralPath $err -Tail 8|Write-Host}
}
