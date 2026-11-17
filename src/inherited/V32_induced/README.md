# V32 induced-source pipeline

This directory is the non-destructive replacement for the V31 trial-average
ROI pipeline. Existing V31 scripts and derivatives remain legacy exploratory
and QC products.

## Scientific estimand

The primary estimand is within-recording percentile-normalized log induced
posterior source energy. Energy is calculated for each good epoch using the
fixed subject-specific SPM MSP inverse operator and averaged only after
squaring. Conditional posterior variance is stored separately.

## Run order

1. `01_equivalence_test/A01_run_induced_equivalence_V32.m`
2. `02_epoch_energy/A02_extract_induced_band_energy_V32.m`
3. `03_subject_maps/A03_build_subject_summaries_V32.m`
4. `04_resolution/A04_compute_resolution_diagnostics_V32.m`
5. `05_frozen_split/A05_freeze_participant_split_V32.m`
6. `06_atlas_scaffold/A06_project_atlas_to_mesh_V32.m`
7. `07_resolution_supports/A07_build_resolution_compatible_supports_V32.m`
8. `08_support_metrics/A08_extract_frozen_support_metrics_V32.m`
9. `09_reliability_candidates/A09_freeze_candidate_family_V32.m`
10. `09_reliability_candidates/A09b_freeze_candidate_family_V2_V32.m`
11. `10_heldout_validation/A10_run_heldout_models_V32.m`
12. `11_physiological_dcm_handoff/A11_build_physiological_DCM_handoff_V32.m`
13. `11_physiological_dcm_handoff/A11b_freeze_DCM_handoff_V2_V32.m`

The cohort extractor refuses to run unless the equivalence gate exists and all
configured comparisons passed.

## Outputs

Outputs are written beneath:

`derivatives/V32_induced/`

Each recording receives an independent MAT file, allowing restart without
holding an 8,196 × recording × band array in memory. The paired stage writes
EC-minus-EO maps within participant.

## Validation status

The equivalence gate was run on 3 August 2026 for `sub-87958013` restEC and
restEO. All eight band-by-condition comparisons passed. Each custom map had
Pearson r = 1.0 (to reported precision) against SPM `contrast.GW`, and the
largest relative error was below 6e-8. See
`derivatives/V32_induced/01_equivalence_test/` for the CSV, MAT file and log.

The cohort stages were also completed on 3 August 2026 after explicit
participant-condition deduplication:

- 610 unique recording maps; zero extraction failures.
- 323 participants: 287 paired EC-minus-EO maps and 36 missing-condition cases.
- 610 successful matrix-free resolution summaries.
- Cohort medians: resolution rank 25, PSF peak displacement 118.7 mm,
  PSF geodesic dispersion 103.8 mm and PSF 80%-mass radius 124.4 mm.

The broad PSF measurements rule out vertex-level anatomical interpretation.
Downstream atlas parcels must be merged or otherwise restricted to spatial
supports compatible with these empirical resolution diagnostics.

One duplicate key (`sub-88006161`, restEO) contained materially different
`edfM` and `redfM` inversions. The frozen override selects the canonical
rereferenced `redfM` file. Both candidates and the rationale are recorded in
the duplicate-resolution audit CSV; the earlier map is retained under
`02_epoch_energy/superseded_duplicate_candidates/`.

The participant split and support-definition stages were completed after the
source estimator was frozen:

- 225 discovery and 98 locked-validation participants, stratified by
  diagnosis, sex, age band and EC/EO availability with seed 31072026;
- a separate label-blind split file excludes diagnosis from support building;
- SPM Neuromorphometrics projection covers 7,962/8,196 vertices (97.1%);
- 103 connected atlas components were evaluated using 424 discovery
  recordings and merged into 20 frozen connected supports;
- the merge profile cosine ranged from 0.875 to 0.980;
- 48,800 recording-level and 22,960 paired-condition support rows were
  exported for downstream reliability and statistical modelling.

The validation participants did not contribute to atlas merging, PSF/CTF
profiles, the support count or representative coordinates. Diagnosis was used
to balance the split but was removed from the table consumed by the spatial
support builder.

Discovery-only odd/even epoch reliability was computed for 424 recordings
without failures. V1 candidate scoring was rejected before validation because
all eight slots collapsed onto four bands from each of two very small supports.
V1 remains preserved as an audit. V2 required at least 50 vertices, percentile-
scaled the four evidence dimensions, and allowed one band per support. It
froze eight distinct support-band candidates (seven beta and one alpha).

The held-out mixed-effects models were then run in the 98 validation
participants using the specification locked in
`10_heldout_validation/A10_CONFIRMATORY_MODEL_SPEC_LOCKED.md`. Zero of the 16
diagnosis or diagnosis-by-condition coefficients survived Holm family-wise
correction. The smallest unadjusted p-value was 0.0752 (beta support 15,
diagnosis coefficient 0.0281 percentile units, 95% CI -0.0029 to 0.0592).
This is a null confirmatory result and should not be reframed as evidence for
a diagnosis-associated source ROI.

A separate diagnosis-blind physiological investigation selected DCM nodes from
paired EC-minus-EO log induced energy. Twelve discovery-shortlisted effects
replicated directionally in validation and survived Holm correction. The first
handoff met its written replication rules but conflicted with the previously
adopted 50-vertex support minimum; it is retained as rejected. The corrected
V2 handoff applies that unchanged size rule and contains six nodes spanning
beta, alpha, theta and delta evidence bands. Only
`A11b_DCM_node_handoff_V2_LOCKED.csv` is approved for DCM construction.

## Interpretation

- `mean_energy`: energy of the posterior conditional mean; primary activity quantity.
- `posterior_variance`: SPM conditional variance contribution; uncertainty quantity.
- `expected_energy`: `mean_energy + posterior_variance`; matches SPM `contrast.GW`.
- `percentile_log_mean_energy`: primary within-recording normalized map.

Do not call these values absolute current density. Do not use raw free energy
to rank participants. Do not perform diagnosis-driven ROI discovery before the
participant-level split and resolution-compatible support construction are
implemented and frozen.

## Not yet implemented

External replication, sensor-level physiological confirmation,
artefact/surrogate robustness and DCM model construction remain downstream.
The current held-out analysis does not support a diagnosis-related regional
power claim. The DCM nodes are instead justified by replicated EC/EO
physiology, and any later diagnosis effect must be tested at the connectivity
level without changing these coordinates.
