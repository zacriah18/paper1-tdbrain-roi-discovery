# Provenance and snapshot boundaries

## Source locations

All paths below are relative to `C:\MATLAB` at snapshot time (17 November 2026).

| Repository destination | Source location | Scope |
|---|---|---|
| `src/preprocessing/` | `2026 TDBRAIN dataset/` | A-E MATLAB scripts and four channel/montage configuration files. |
| `src/roi_discovery/V37_DCM_concordant_ROI_discovery/` | `2026 TDBRAIN V31 source ROI discovery/V37_DCM_concordant_ROI_discovery/` | V37 source, runners, tests/docs where present, method lock and README. |
| `src/roi_discovery/V37_1_covariate_conditioned_discovery/` | `2026 TDBRAIN V31 source ROI discovery/V37_1_covariate_conditioned_discovery/` | V37.1 source, runners, tests, locks and interpretation docs; `.codex_tmp` excluded. |
| `src/inherited/V32_induced/` through `V36_six_node_csd_dcm/` | matching version folders in the Paper 1 analysis tree | MATLAB/PowerShell source and Markdown branch context only; included because V37 setup adds these roots to the MATLAB path and inherits V36 configuration. |

The exact source and destination path and SHA-256 for each copied file are in `manifests/source_snapshot.csv`. The hashes are a snapshot comparison aid, not a scientific validation certificate. No source file in the original folders was modified.

## Exclusions

The repository does not contain raw BDF/EEG, participant-level clinical/demographic tables, participant anatomical files, source inversion MAT/DAT outputs, derivatives, fit results, permutation shards, caches, execution logs, or installed MATLAB/SPM/FieldTrip toolboxes. Dataset stages F/G and their outputs are outside the initial scope. Historical result files and audit outputs are not copied just because they are adjacent to code.

Four upstream channel/montage configuration files are included because preprocessing/source reconstruction refers to them. Their non-participant status and redistribution suitability still require review before any public release.

## Current source fidelity and portability

The selected scripts/configuration were copied without path or scientific-default edits. Their absolute `C:\MATLAB` roots remain. In particular, V37 config calls V36 config, and V37/V37.1 setup functions add V32-V36 roots to the MATLAB path. This repository therefore records a faithful code snapshot but is not yet a portable checkout. Any portability refactor must be made here, retain this manifest as the source snapshot record, and document source/destination changes separately.

## Scientific interpretation limits

- Stage E is SPM source inversion; it is not ROI-level DCM.
- V37 exact IMG supports differ from historical V34 geodesic patches.
- V37.1's confirmation cohort was previously used by V32; it is internal held-out confirmation, not untouched external validation.
- Regional observability does not establish recovery of DCM parameters or architecture.

Use the source branch locks and READMEs for detailed definitions and claim boundaries.
