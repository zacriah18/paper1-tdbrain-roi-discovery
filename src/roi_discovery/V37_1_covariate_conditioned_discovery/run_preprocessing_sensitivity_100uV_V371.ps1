param([switch]$Worker)
$ErrorActionPreference='Stop'
$pipeline='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V37_1_covariate_conditioned_discovery'
$source='C:\MATLAB\2026 TDBRAIN dataset'
$dName='D_artifact_reject_shortlist_jump100_sensitivity'
$eName='E_source_reconstruction_shortlist_QC_jump100_sensitivity'
$logRoot=Join-Path $source 'derivatives\V371_jump100_sensitivity_logs'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$manifest=Join-Path $logRoot 'coordinator.csv'
$status=Join-Path $logRoot 'phase_status.csv'

if(!$Worker){
    if(Test-Path $manifest){
        $old=Import-Csv -LiteralPath $manifest | Select-Object -First 1
        $active=Get-Process -Id ([int]$old.pid) -ErrorAction SilentlyContinue
        if($active){Write-Output 'The 100 uV preprocessing sensitivity coordinator is already active.'; exit 0}
    }
    $stdout=Join-Path $logRoot 'coordinator_stdout.log'
    $stderr=Join-Path $logRoot 'coordinator_stderr.log'
    $p=Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$PSCommandPath+'"'),'-Worker' `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    try{$p.PriorityClass='BelowNormal'}catch{}
    [pscustomobject]@{pid=$p.Id;started=(Get-Date);stdout=$stdout;stderr=$stderr} | Export-Csv -LiteralPath $manifest -NoTypeInformation
    Write-Output "Started 100 uV preprocessing sensitivity coordinator PID $($p.Id)."
    exit 0
}

$dRoot=Join-Path $source ("derivatives\$dName")
$eRoot=Join-Path $source ("derivatives\$eName")
$dSummary=Join-Path $dRoot 'D_artifact_reject_shortlist_summary.csv'
$eStatus=Join-Path $eRoot 'E_source_reconstruction_status.csv'

function Write-Phase([string]$phase,[string]$state,[int]$childProcessId,[string]$message){
    [pscustomobject]@{updated=(Get-Date);phase=$phase;state=$state;child_pid=$childProcessId;message=$message} | `
        Export-Csv -LiteralPath $status -NoTypeInformation
}

if(Test-Path $eStatus){Write-Phase 'complete' 'complete' 0 'Existing complete Stage-E status found'; exit 0}

$dReady=$false
if(Test-Path $dSummary){$dRows=@(Import-Csv -LiteralPath $dSummary);$dReady=($dRows.Count -eq 704)}
if(!$dReady){
    $env:TDBRAIN_D_JUMP_THRESHOLD_UV='100'
    $env:TDBRAIN_D_OUTPUT_NAME=$dName
    $dDriver=Join-Path $source 'D_artifact_reject_shortlist.m'
    $dExpr="run('$($dDriver -replace "'","''")')"
    $dOut=Join-Path $logRoot 'D_stdout.log'; $dErr=Join-Path $logRoot 'D_stderr.log'
    Write-Phase 'D_artifact_rejection' 'starting' 0 '100 uV adjacent-jump guard; 1000 uV peak-to-peak guard'
    $d=Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' -ArgumentList '-batch',('"'+$dExpr+'"') `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $dOut -RedirectStandardError $dErr
    try{$d.PriorityClass='BelowNormal'}catch{}
    Write-Phase 'D_artifact_rejection' 'running' $d.Id '100 uV branch'
    $d.WaitForExit(); $d.Refresh()
    if(Test-Path $dSummary){$dRows=@(Import-Csv -LiteralPath $dSummary);$dReady=($dRows.Count -eq 704)}
    if(!$dReady){Write-Phase 'D_artifact_rejection' 'failed' $d.Id "No complete 704-row summary; MATLAB exit $($d.ExitCode)"; exit 1}
}
Write-Phase 'D_artifact_rejection' 'complete' 0 'Verified 704-row summary; launching Stage E'

Remove-Item Env:TDBRAIN_D_JUMP_THRESHOLD_UV,Env:TDBRAIN_D_OUTPUT_NAME -ErrorAction SilentlyContinue
$env:TDBRAIN_E_D_INPUT_NAME=$dName
$env:TDBRAIN_E_OUTPUT_NAME=$eName
$env:TDBRAIN_E_SAVE_QC_IMAGES='0'
$eDriver=Join-Path $source 'E_source_reconstruction_shortlist.m'
$eExpr="run('$($eDriver -replace "'","''")')"
$eOut=Join-Path $logRoot 'E_stdout.log'; $eErr=Join-Path $logRoot 'E_stderr.log'
Write-Phase 'E_source_reconstruction' 'starting' 0 'Template SPM inversion; QC image rendering disabled'
$e=Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' -ArgumentList '-batch',('"'+$eExpr+'"') `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput $eOut -RedirectStandardError $eErr
try{$e.PriorityClass='BelowNormal'}catch{}
Write-Phase 'E_source_reconstruction' 'running' $e.Id 'jump-100 sensitivity source branch'
$e.WaitForExit()
$e.Refresh()
if(!(Test-Path $eStatus)){Write-Phase 'E_source_reconstruction' 'failed' $e.Id "No final status table; MATLAB exit $($e.ExitCode)"; exit 1}
Write-Phase 'complete' 'complete' $e.Id 'D and E sensitivity branches completed'
Remove-Item Env:TDBRAIN_E_D_INPUT_NAME,Env:TDBRAIN_E_OUTPUT_NAME,Env:TDBRAIN_E_SAVE_QC_IMAGES -ErrorAction SilentlyContinue
