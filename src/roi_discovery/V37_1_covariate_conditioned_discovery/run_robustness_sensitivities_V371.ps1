param(
    [ValidateSet('high_qc','exclude_repeated_sessions','both')]
    [string]$Sensitivity='both'
)
$ErrorActionPreference='Stop'
$pipeline='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V37_1_covariate_conditioned_discovery'
$derivative='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$logs=Join-Path $derivative 'logs\robustness_sensitivities'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$manifest=Join-Path $logs 'sensitivity_pids.csv'

if(Test-Path $manifest){
    $active=@(Import-Csv -LiteralPath $manifest | ForEach-Object {
        Get-Process -Id ([int]$_.pid) -ErrorAction SilentlyContinue
    })
    if($active.Count){Write-Output "$($active.Count) robustness sensitivity processes are already active."; exit 0}
}

$jobs=if($Sensitivity -eq 'both'){@('high_qc','exclude_repeated_sessions')}else{@($Sensitivity)}
$driver=Join-Path $pipeline '08_robustness_sensitivities\A18_run_discovery_sensitivity_V371.m'
$rows=@()
foreach($job in $jobs){
    $env:TDBRAIN_V371_SENSITIVITY=$job
    $expr="run('$($driver -replace "'","''")')"
    $stdout=Join-Path $logs ("{0}_stdout.log" -f $job)
    $stderr=Join-Path $logs ("{0}_stderr.log" -f $job)
    $p=Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' `
        -ArgumentList '-batch',('"'+$expr+'"') -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    try{$p.PriorityClass='BelowNormal'}catch{}
    $rows += [pscustomobject]@{sensitivity=$job;pid=$p.Id;started=(Get-Date);stdout=$stdout;stderr=$stderr}
}
Remove-Item Env:TDBRAIN_V371_SENSITIVITY -ErrorAction SilentlyContinue
$rows | Export-Csv -LiteralPath $manifest -NoTypeInformation
Write-Output "Started $($rows.Count) V37.1 robustness sensitivity process(es)."
