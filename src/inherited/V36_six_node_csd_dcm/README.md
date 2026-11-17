# V36: six-node cross-spectral DCM long run

V36 implements the V35 six-node handoff as an SPM cross-spectral DCM using a canonical microcircuit at each node and SPM's distributed `IMG` observation model.

Run order:

1. `01_preflight/A01_preflight_exact_SPM_IMG_V36.m`
2. `02_first_level/A02_run_first_level_CSD_DCM_V36.m`
3. `03_qc/A03_summarize_first_level_DCM_V36.m`

The model and interpretation lock is `A00_MODEL_HYPOTHESIS_LOCK.md`.

The first-level runner is resumable. A saved model is considered complete only if it contains finite `F`, `Ep`, and `Cp` fields. The checkpoint CSV is rewritten after every recording. Environment variables `TDBRAIN_V36_MAX_RECORDINGS`, `TDBRAIN_V36_START_ROW`, `TDBRAIN_V36_END_ROW`, and `TDBRAIN_V36_RETRY_ERRORS` support smoke tests, chunked execution, and explicit error retry.

Only the H5 parent model is inverted. H1–H4 are nested hypotheses reserved for Bayesian model reduction after first-level QC. Discovery recordings are in scope; validation remains frozen.

For an unattended run, execute `run_long_V36.ps1`. It refuses to start if its recorded MATLAB PID is still alive, launches MATLAB with a hidden window, and writes separate stdout/stderr logs. `monitor_long_V36.ps1` reports process state, checkpoint counts, percent complete, and the latest log lines. Re-running the launcher after interruption resumes from independently validated model files.

If local PowerShell script execution is restricted, monitor with:

`powershell -NoProfile -ExecutionPolicy Bypass -File "C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V36_six_node_csd_dcm\monitor_long_V36.ps1"`
