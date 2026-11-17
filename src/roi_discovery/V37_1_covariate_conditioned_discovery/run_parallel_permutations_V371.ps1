param([ValidateRange(1,8)][int]$Workers=2,[ValidateRange(4,1000)][int]$StartIndex=4)
$ErrorActionPreference='Stop'
$pipeline='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V37_1_covariate_conditioned_discovery'
$d='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V37_1_covariate_conditioned_discovery'
$logs=Join-Path $d 'logs\parallel_permutations';New-Item -ItemType Directory -Force -Path $logs|Out-Null
$manifest=Join-Path $logs 'worker_pids.csv'
if(Test-Path $manifest){$active=@(Import-Csv $manifest|ForEach-Object{Get-Process -Id ([int]$_.pid) -ErrorAction SilentlyContinue});if($active.Count){Write-Output "$($active.Count) permutation workers are already active.";exit 0}}
$rows=@();$driver=Join-Path $pipeline '03_permutation\A03b_run_parallel_permutation_worker_V371.m';$expr="run('$($driver -replace "'","''")')"
for($w=1;$w-le$Workers;$w++){
    $env:TDBRAIN_V371_WORKER_ID=[string]$w;$env:TDBRAIN_V371_WORKER_COUNT=[string]$Workers;$env:TDBRAIN_V371_START_INDEX=[string]$StartIndex
    $stdout=Join-Path $logs ("worker_{0:D2}_stdout.log" -f $w);$stderr=Join-Path $logs ("worker_{0:D2}_stderr.log" -f $w)
    $p=Start-Process -FilePath 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' -ArgumentList '-batch',('"'+$expr+'"') `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    try{$p.PriorityClass='BelowNormal'}catch{};$rows+=[pscustomobject]@{worker=$w;pid=$p.Id;started=(Get-Date);stdout=$stdout;stderr=$stderr}
}
Remove-Item Env:TDBRAIN_V371_WORKER_ID,Env:TDBRAIN_V371_WORKER_COUNT,Env:TDBRAIN_V371_START_INDEX -ErrorAction SilentlyContinue
$rows|Export-Csv -LiteralPath $manifest -NoTypeInformation
Write-Output "Started $Workers independent V37.1 permutation workers at index $StartIndex."
