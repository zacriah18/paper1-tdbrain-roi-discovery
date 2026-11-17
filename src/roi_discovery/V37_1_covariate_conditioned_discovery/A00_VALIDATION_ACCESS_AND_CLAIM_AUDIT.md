# V37.1 Validation Access and Claim Audit

**Freeze date:** 8 August 2026  
**Validation access began:** 8 August 2026, approximately 14:50 Australia/Sydney  
**Frozen manifest SHA-256:** `82f44959886de417a617c8b845092b23c02f0c9e6cfc50aef9f35d7c703c24ed`

## Frozen hierarchy

### Primary predictive model

- Model size: K = 1, selected by the prespecified participant-bootstrap one-standard-error rule.
- Patch 385: `[21.0443, -96.4770, -17.5839]` mm.
- Exact 16 mm support: 32 vertices.
- Primary endpoint: frozen combined-model log loss minus the frozen demographic-model log loss, expressed as improvement where positive.
- Primary inference: 10,000 label permutations within age-band, sex, and EC/EO-availability blocks.

### Secondary DCM-sized family

- Model size: K = 4, the smallest DCM-sized set within the same one-standard-error envelope.
- Patches: 385, 5, 261, and 314.
- This family is secondary and cannot replace the K = 1 primary model after validation outcomes are viewed.
- The template structural lead-field audit passed: pairwise redundancy gate passed; dominant-pattern joint rank = 4 under eight channel modes.
- Subject-level sensor-space CSD sensitivity remains pending and is required before a Paper 2 DCM handoff.

## Discovery evidence at freeze

- Best mean held-out log loss occurred at K = 6: 0.6211.
- The one-standard-error rule selected the **training-only adaptive K = 1 selector**: log loss 0.6343, AUC 0.694, incremental log loss 0.0138.
- The **training-only adaptive K = 4 selector** remained inside the envelope: log loss 0.6266, AUC 0.717, incremental log loss 0.0215.
- The K = 1 bootstrap interval for discovery incremental log loss included zero; the completed full-search permutation remains the global discovery-stage inferential result.

These cross-validated values belong to the rule that regenerated and ranked patches inside every training split; the selected coordinates varied across folds. They are not unbiased performance estimates for the final aggregate coordinates. Cross-validation performed after fixing patch 385 or the final four-coordinate family is post-selection descriptive only. The current 98-person confirmation is therefore the first test of those exact frozen coordinates under the stated V37.1 hierarchy.

## Claim tier

The 98 participants were excluded from every V37/V37.1 selection, tuning, peer comparison, and model-freeze calculation. However, files show that the same frozen split was used for the earlier V32 held-out analysis on 3 August 2026. Consequently, the current test is:

> an internal held-out confirmation for the frozen V37.1 pipeline, not an untouched study-program-level external validation.

This limitation must appear in the manuscript and presentation. A future cohort is required for a genuinely external replication claim.

## Post-access prohibitions

After validation access began, the following cannot be changed in response to outcomes:

- primary or secondary ROI membership;
- coordinates or exact vertex supports;
- preprocessing, normalization, spectral basis, or coefficient order;
- discovery-fitted coefficients and standardization constants;
- primary endpoint, permutation blocks, permutation count, or direction;
- exclusion and missing-data rules; or
- the primary/secondary hierarchy.

Any additional model, threshold, ROI substitution, EC-only/EO-only analysis, regional component analysis, or QC investigation must be labelled secondary, sensitivity, or exploratory as appropriate.
