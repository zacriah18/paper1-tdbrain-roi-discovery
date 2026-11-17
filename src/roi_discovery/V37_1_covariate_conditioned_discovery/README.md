# V37.1: covariate-conditioned DCM-concordant discovery

This pipeline preserves V37 and adds conditional nuisance adjustment,
global conditional permutation, QC negative controls and a sensor-spectrum
comparator. It contains an explicit guard against reading the 98 validation
participants.

## Run order

1. `01_folds/A01_freeze_nested_folds_V371.m`
2. `02_conditioned_models/A02_run_conditioned_nested_models_V371.m`
3. `03_permutation/A03_run_conditional_full_pipeline_permutations_V371.m`
4. `04_sensor_comparator/A04_extract_sensor_spectra_V371.m`
5. `04_sensor_comparator/A05_assemble_sensor_participant_features_V371.m`
6. `04_sensor_comparator/A06_run_sensor_comparator_V371.m`
7. `04_sensor_comparator/A07_compare_source_and_sensor_V371.m`
8. `05_peer_set_comparison/A08_run_peer_set_comparison_V371.m`

Use `run_long_V371.ps1 -StartPermutation` to run the observed model and
then the checkpointed conditional permutation test. Use
`monitor_long_V371.ps1` (or invoke it with PowerShell execution-policy
bypass where local policy requires it) to monitor completion.

The sensor comparator is a separate resumable job:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_sensor_V371.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\monitor_sensor_V371.ps1
```

The fixed 98-person cohort is deliberately not opened automatically. A
human review of the observed, permutation, QC-only and sensor-comparator
results precedes the separate ROI/model freeze and validation run.

## Peer-set comparison before validation

The completed permutation test supports the full 452-patch search, but does
not prove that one DCM-sized subset is uniquely optimal. Stage A08 therefore
regenerates all candidate sets inside each outer training split, compares
sets of size 1--6 using held-out log loss, applies participant-clustered
uncertainty, and audits spatial and lead-field redundancy. The 98 validation
participants remain inaccessible throughout this stage.

Run a separate one-repeat smoke analysis first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_peer_set_V371.ps1 -Smoke
powershell -NoProfile -ExecutionPolicy Bypass -File .\monitor_peer_set_V371.ps1 -Smoke
```

After the smoke outputs are reviewed, start the resumable full analysis:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_peer_set_V371.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\monitor_peer_set_V371.ps1
```

Only a completed non-smoke run that passes the structural gate can write
`A08_validation_freeze_manifest.json`. Writing that file does not itself
open or score the validation cohort.

After the manifest and claim audit are reviewed, the frozen internal
confirmation is run once with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_validation_V371.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\monitor_validation_V371.ps1
```

This extracts all 452 patches in the 98 participants because the frozen
participant-relative normalization requires the whole spatial landscape;
only then are the frozen K=1 primary and K=4 secondary models scored. The
same cohort was used previously by V32, so this is an internal held-out
V37.1 confirmation rather than an untouched external validation.

## Accelerated permutation resume

The original sequential runner completed permutations 1--3. The optimized
solver is numerically equivalent to the frozen implementation (maximum
regression-test coefficient error `1.02e-14`) and reproduces the interrupted
real-data folds. Permutation 4 completed in approximately five minutes and
is stored as an independent atomic shard.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_parallel_permutations_V371.ps1 -Workers 2 -StartIndex 4
powershell -NoProfile -ExecutionPolicy Bypass -File .\monitor_parallel_permutations_V371.ps1
```

Each worker owns a disjoint permutation sequence and writes one MAT file per
completed permutation. `A03c_aggregate_parallel_permutations_V371.m` merges
the legacy checkpoint and shards without refitting.

Permutation and sensor extraction are separate resumable jobs. Validation
participants are not accessed by any V37.1 script.
# Pre-DCM validation gate

The frozen four-node handoff now has two additional validation-cohort audits in `07_pre_DCM_gate`:

- `A14_run_EO_sensor_ocular_proxy_audit_V371.m` tests EO sensor spectra and Fp1/Fp2 ocular proxies without changing ROI selection.
- `A16_run_validation_CSD_observability_V371.m` measures subject-recording node visibility, unique projected patterns, joint rank and pairwise CSD overlap in SPM's eight channel modes.

The prespecified pass criteria and nested four-model connectivity family are locked in `A15_PRE_DCM_GATE_AND_CONNECTIVITY_FAMILY_LOCK.md`.
