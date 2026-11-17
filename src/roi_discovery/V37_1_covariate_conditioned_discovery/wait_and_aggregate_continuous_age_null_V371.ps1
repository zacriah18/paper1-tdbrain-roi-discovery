param([switch]$Worker)
$ErrorActionPreference='Stop'
$pipeline='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V37_1_covariate_conditioned_discovery'
$derivative='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$out=Join-Path $derivative '08_robustness_sensitivities\continuous_age_parametric_null'
$logs=Join-Path $derivative 'logs\continuous_age_parametric_null'
$manifest=Join-Path $logs 'worker_pids.csv'
$finalizerManifest=Join-Path $logs 'finalizer_pid.csv'
$finalizerStatus=Join-Path $logs 'finalizer_status.csv'
$summary=Join-Path $out 'A19c_continuous_age_null_summary.csv'
$shards=Join-Path $out 'shards'
New-Item -ItemType Directory -Force -Path $logs | Out-Null

if(!$Worker){
    if(Test-Path $finalizerManifest){
        $old=Import-Csv -LiteralPath $finalizerManifest | Select-Object -First 1
        $active=Get-Process -Id ([int]$old.pid) -ErrorAction SilentlyContinue
        if($active){Write-Output 'Continuous-age null finalizer is already active.'; exit 0}
    }
    $stdout=Join-Path $logs 'finalizer_stdout.log'; $stderr=Join-Path $logs 'finalizer_stderr.log'
    $p=Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$PSCommandPath+'"'),'-Worker' `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    try{$p.PriorityClass='BelowNormal'}catch{}
    [pscustomobject]@{pid=$p.Id;started=(Get-Date);stdout=$stdout;stderr=$stderr} | Export-Csv -LiteralPath $finalizerManifest -NoTypeInformation
    Write-Output "Started continuous-age null finalizer PID $($p.Id)."
    exit 0
}

while($true){
    if(Test-Path $summary){
        [pscustomobject]@{updated=(Get-Date);state='complete';shards=1000;message='Aggregate already exists'} | Export-Csv -LiteralPath $finalizerStatus -NoTypeInformation
        exit 0
    }
    $count=0; if(Test-Path $shards){$count=@(Get-ChildItem -LiteralPath $shards -Filter 'bootstrap_*.mat').Count}
    $active=@()
    if(Test-Path $manifest){$active=@(Import-Csv -LiteralPath $manifest | ForEach-Object {Get-Process -Id ([int]$_.pid) -ErrorAction SilentlyContinue})}
    [pscustomobject]@{updated=(Get-Date);state='waiting';shards=$count;message="$($active.Count) workers active"} | Export-Csv -LiteralPath $finalizerStatus -NoTypeInformation
    if($count -ge 1000){break}
    if($active.Count -eq 0){
        [pscustomobject]@{updated=(Get-Date);state='failed';shards=$count;message='Workers ended before 1000 shards'} | Export-Csv -LiteralPath $finalizerStatus -NoTypeInformation
        exit 1
    }
    Start-Sleep -Seconds 60
}

$driver=Join-Path $pipeline '08_robustness_sensitivities\A19c_aggregate_continuous_age_null_V371.m'
$expr="run('$($driver -replace "'","''")')"
[pscustomobject]@{updated=(Get-Date);state='aggregating';shards=1000;message='Running A19c audit and aggregate'} | Export-Csv -LiteralPath $finalizerStatus -NoTypeInformation
$p=Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' -ArgumentList '-batch',('"'+$expr+'"') -WindowStyle Hidden -PassThru -Wait
if($p.ExitCode -ne 0){
    [pscustomobject]@{updated=(Get-Date);state='failed';shards=1000;message="Aggregator MATLAB exit $($p.ExitCode)"} | Export-Csv -LiteralPath $finalizerStatus -NoTypeInformation
    exit $p.ExitCode
}
[pscustomobject]@{updated=(Get-Date);state='complete';shards=1000;message='A19c aggregate and audit complete'} | Export-Csv -LiteralPath $finalizerStatus -NoTypeInformation
