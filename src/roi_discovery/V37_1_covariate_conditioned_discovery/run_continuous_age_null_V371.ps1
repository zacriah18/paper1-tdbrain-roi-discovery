param([ValidateRange(1,8)][int]$Workers=2,[ValidateRange(1,1000)][int]$Count=1000)
$ErrorActionPreference='Stop'
$pipeline='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V37_1_covariate_conditioned_discovery'
$derivative='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$out=Join-Path $derivative '08_robustness_sensitivities\continuous_age_parametric_null'
$logs=Join-Path $derivative 'logs\continuous_age_parametric_null'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$freeze=Join-Path $out 'A19a_continuous_age_null_freeze.mat'
if(!(Test-Path $freeze)){throw 'Continuous-age null freeze is missing. Run A19a first.'}
$manifest=Join-Path $logs 'worker_pids.csv'
if(Test-Path $manifest){
    $active=@(Import-Csv -LiteralPath $manifest | ForEach-Object {Get-Process -Id ([int]$_.pid) -ErrorAction SilentlyContinue})
    if($active.Count){Write-Output "$($active.Count) continuous-age null workers are already active."; exit 0}
}
$driver=Join-Path $pipeline '08_robustness_sensitivities\A19b_run_continuous_age_null_worker_V371.m'
$rows=@()
for($worker=1;$worker -le $Workers;$worker++){
    $env:TDBRAIN_V371_NULL_WORKER_ID=[string]$worker
    $env:TDBRAIN_V371_NULL_WORKER_COUNT=[string]$Workers
    $env:TDBRAIN_V371_NULL_COUNT=[string]$Count
    $expr="run('$($driver -replace "'","''")')"
    $stdout=Join-Path $logs ("worker_{0:D2}_stdout.log" -f $worker)
    $stderr=Join-Path $logs ("worker_{0:D2}_stderr.log" -f $worker)
    $p=Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' `
        -ArgumentList '-batch',('"'+$expr+'"') -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    try{$p.PriorityClass='BelowNormal'}catch{}
    $rows += [pscustomobject]@{worker=$worker;pid=$p.Id;started=(Get-Date);stdout=$stdout;stderr=$stderr}
}
Remove-Item Env:TDBRAIN_V371_NULL_WORKER_ID,Env:TDBRAIN_V371_NULL_WORKER_COUNT,Env:TDBRAIN_V371_NULL_COUNT -ErrorAction SilentlyContinue
$rows | Export-Csv -LiteralPath $manifest -NoTypeInformation
Write-Output "Started $Workers continuous-age null workers for $Count bootstraps."
