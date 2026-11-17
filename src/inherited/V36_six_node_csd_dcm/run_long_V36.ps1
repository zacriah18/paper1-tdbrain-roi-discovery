$ErrorActionPreference = 'Stop'
$pipelineRoot = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V36_six_node_csd_dcm'
$outputRoot = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\derivatives\V36_six_node_csd_dcm\02_first_level'
$matlabExe = 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe'
$pidFile = Join-Path $outputRoot 'V36_long_run.pid'
$stdout = Join-Path $outputRoot 'V36_long_run_stdout.log'
$stderr = Join-Path $outputRoot 'V36_long_run_stderr.log'

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
if (Test-Path -LiteralPath $pidFile) {
    $oldPid = [int](Get-Content -LiteralPath $pidFile -Raw)
    if (Get-Process -Id $oldPid -ErrorAction SilentlyContinue) {
        throw "V36 is already running with PID $oldPid"
    }
}

$entry = "setenv('TDBRAIN_V36_MAX_RECORDINGS',''); setenv('TDBRAIN_V36_START_ROW','1'); setenv('TDBRAIN_V36_END_ROW',''); setenv('TDBRAIN_V36_RETRY_ERRORS','false'); addpath('$pipelineRoot\02_first_level'); A02_run_first_level_CSD_DCM_V36;"
$process = Start-Process -FilePath $matlabExe -ArgumentList @('-batch', ('"' + $entry + '"')) `
    -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
[System.IO.File]::WriteAllText($pidFile, [string]$process.Id)
[pscustomobject]@{ PID = $process.Id; Stdout = $stdout; Stderr = $stderr; Status = (Join-Path $outputRoot 'A02_first_level_run_status.csv') }
