# V37.1 pre-DCM gate and connectivity-family lock

Locked before the full subject-recording CSD audit was inspected on 8 August 2026.

## Scope

This gate determines whether the four already-frozen 16 mm IMG regions remain separately observable in the sensor/CSD representation used by SPM. It does **not** estimate effective connectivity, establish causal direction, or permit replacement of a node after looking at validation results.

Frozen node order:

1. Patch 385 — right occipital pole / occipital fusiform / lingual cortex.
2. Patch 5 — left transverse temporal gyrus / planum polare / posterior insula.
3. Patch 261 — right entorhinal / parahippocampal / ventral temporal cortex.
4. Patch 314 — right precuneus / posterior cingulate cortex.

The exact coordinates and 16 mm vertex supports remain those in `05_peer_set_comparison/A08_DCM_candidate_ROI_set.csv` and the validation-freeze manifest. No centre, radius, support, spectral basis, or node order may change in this audit.

## Prespecified technical gate

The four-node handoff is technically supported only if all of the following hold:

- at least 95% of usable EC/EO recordings have four linearly independent dominant projected lead-field patterns;
- the fifth percentile of the minimum node-unique residual norm is greater than 0.10;
- the median joint effective rank is at least 2.5 of four;
- no node has effectively zero projected visibility or zero unique CSD energy across the cohort;
- results are reported separately for EC and EO so that one condition cannot conceal collapse in the other;
- no processing or extraction errors selectively remove a diagnosis group.

Pairwise regional-subspace correlations are descriptive warnings, not automatic rejection criteria. A 16 mm IMG region contains six spatial modes and those six-dimensional subspaces can overlap strongly in 26-channel EEG even when their dominant patterns remain jointly non-collapsed.

## Ocular and sensor-level gate

The inversion-visible files contain 26 EEG channels and no dedicated EOG channel. Fp1 and Fp2 are therefore only frontal-polar ocular proxies. The audit reports:

- a nuisance-conditioned six-component EO spectral test at every channel;
- 10,000 label permutations within age-band, sex, and condition-availability blocks;
- Holm correction across 26 channels;
- the descriptive correlation of each channel's frozen spectral direction with the EO patch-385 source score.

A Holm-positive Fp1/Fp2 result or a very large frontal-polar/source-score correlation is a confound warning requiring stronger ocular sensitivity analysis. A negative proxy result cannot prove the absence of ocular contamination because dedicated EOG is unavailable.

## Prespecified four-model CSD-DCM family

SPM matrix convention is `A(target, source)`.

- **H1 core posterior-medial:** reciprocal occipital–precuneus and precuneus–medial-temporal hierarchical connections, plus reciprocal auditory/insula–precuneus lateral coupling.
- **H2:** H1 plus reciprocal occipital–medial-temporal coupling.
- **H3:** H2 plus reciprocal auditory/insula–medial-temporal lateral coupling.
- **H4 parent:** H3 plus reciprocal auditory/insula–occipital cross-modal coupling.

H4 is the first-level parent model. H1–H3 are nested reductions to be compared with Bayesian model reduction/averaging. EC and EO are to be estimated and reported separately before any condition contrast. The current validation results may support the regional handoff, but connection existence, direction, group effects, and predictive effective-connectivity biomarkers belong to the subsequent DCM paper.

## Decision language

- **Pass:** suitable for a frozen four-node CSD-DCM feasibility handoff.
- **Qualified pass:** observable, but a named sensor/confound warning must accompany the handoff and be tested in DCM sensitivity analyses.
- **Fail:** do not invert this four-node family; return to a prespecified lower-node model or collect more informative measurements. Do not choose replacement nodes from the consumed validation cohort.
