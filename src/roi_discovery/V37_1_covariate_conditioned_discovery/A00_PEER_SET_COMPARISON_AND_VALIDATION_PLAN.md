# V37.1 Peer-Set Comparison and Validation Plan

**Status:** Pre-validation methodology lock  
**Date:** 8 August 2026  
**Scope:** Paper 1 ROI discovery and confirmation; DCM parameter estimation remains Paper 2.

## 1. Purpose

The discovery analysis asks whether Bayesian-inverted resting EEG contains a reproducible, diagnosis-related regional signal that can support a compact, biologically plausible ROI model for later DCM. It does not claim that source amplitudes are direct measurements of cortical current, that a selected region is causal, or that the first stable shortlist is the uniquely optimal ROI set.

The completed V37.1 analysis provides evidence that the **full 452-patch neural search procedure** adds predictive information beyond age and sex. Before the 98 held-out participants are opened, a separate peer-set comparison is required to convert that search-level result into one frozen, DCM-sized ROI model.

## 2. Evidence already established

- Discovery cohort: 225 participants.
- Untouched confirmation cohort: 98 participants; validation access remains locked.
- Eligible regional supports: 452 exact 16 mm patches.
- Each patch is represented by six sensor-visible spatial modes and then six fixed spectral-shape coefficients.
- Covariate-conditioned repeated nested cross-validation compared demographics only, neural features only, and demographics plus neural features.
- Observed combined-model improvement over demographics: \(\Delta\) log loss = 0.0224 and \(\Delta\) AUC = 0.0410.
- The conditional full-pipeline permutation test gave \(p=0.001998\) for incremental log loss and \(p=0.007992\) for incremental AUC.

These results support a **non-random search-level neural signal**. They do not establish that the previously reported four-patch shortlist is the best four-node model, that each patch is independently significant, or that any connection is causal.

## 3. Analysis unit and DCM concordance

The participant is the independent sampling unit. Age and sex are nuisance variables used to condition prediction and assess incremental neural information; they cannot select an ROI.

For each participant and patch:

1. Retain the exact cortical vertices within 16 mm of the patch centre.
2. Decompose the regional lead field into six sensor-visible spatial modes.
3. Reconstruct six regional time series from the subject-specific Bayesian inverse operator.
4. Estimate 4–45 Hz power in fixed windows and average power across the six spatial modes, epochs, and windows.
5. Apply participant-relative spatial normalization.
6. Compress the 42-point log spectrum into six fixed spectral-shape coefficients.

The resulting 452 × 6 neural feature matrix is visible to the ROI selection model and structurally aligned with the regional basis later supplied to DCM. Demographic and quality-control variables are never part of the ROI coefficient groups.

## 4. Peer-set comparison: training-only construction

All candidate construction must occur inside the training portion of each outer fold. The corresponding outer-test participants must not influence patch ranking, equivalence grouping, model size, or representative selection.

### 4.1 Re-estimate regional evidence

Within each outer training split:

1. Repeat the inner sparse-group logistic regression used in V37.1.
2. Record each patch group's selection frequency and mean six-coefficient group norm across inner resamples.
3. Rank patches lexicographically by selection frequency and then group norm. Use patch identifier only as a deterministic final tie-break.

### 4.2 Collapse spatially indistinguishable candidates

Treat patches as members of the same equivalence group when either:

- their centres are separated by less than 16 mm; or
- their regional lead fields have RMS canonical correlation greater than or equal to 0.80.

Within each equivalence group, retain the highest-ranked representative. Record all displaced alternatives so that the result is interpreted at regional rather than single-coordinate precision.

### 4.3 Generate explicit DCM-sized peer sets

Construct nested candidate sets of size \(K=1,\ldots,6\) from the ordered, non-redundant regional representatives. Also evaluate the following prespecified peers where applicable:

- the original V37 selection rule regenerated within the outer training split;
- single-region models;
- leave-one-region-out versions of multi-region sets;
- substitutions within a lead-field equivalence group;
- sparse-group regularization-path sets of the same size; and
- redundancy- and rank-matched random regional sets as negative comparators.

This is a comparison of explicit, reproducible candidates. It is not an exhaustive search over all \({452 \choose K}\) combinations, which would be computationally prohibitive and would substantially increase selection optimism.

The previously published V37 four coordinates may be shown as a descriptive benchmark, but they were derived using the full discovery cohort and therefore cannot be treated as an unbiased outer-test candidate. Any inferential comparison of the V37 approach must regenerate its complete selection and pruning rule inside the outer training split.

## 5. Outer-fold comparison and model-size rule

For every outer fold, refit each candidate using training participants only and score the untouched outer-test participants.

Primary comparison endpoint:

- held-out log loss for demographics plus neural features relative to demographics only.

Secondary endpoints:

- AUC;
- Brier score;
- balanced accuracy, sensitivity, and specificity;
- calibration intercept and slope; and
- selection and spatial stability.

Choose the **smallest value of K whose mean held-out log loss is within one standard error of the best-performing K**. Estimate this uncertainty from participant-level out-of-fold loss differences using a participant-clustered bootstrap, so that repeated appearances of the same participant across the 25 evaluations are not counted as independent observations. Held-out log loss determines model size; AUC and stability describe the solution and resolve otherwise equivalent candidates, but cannot override materially worse log loss.

## 6. Sensor-identifiability gate

Before a candidate can be frozen for DCM, audit:

- exact combined regional lead-field rank;
- pairwise RMS canonical correlations;
- joint effective rank under the planned eight channel modes;
- whether the proposed nodes collapse into fewer observable sensor patterns; and
- sensor-space cross-spectral sensitivity to each node.

If a set fails the joint identifiability audit, select the next-ranked non-redundant representative using the same training-only ordering, or reduce K according to the one-standard-error rule. Do not manually substitute a biologically attractive region after viewing test outcomes.

## 7. Full-discovery refit and freeze manifest

After the peer-set rule is fixed, apply it once to all 225 discovery participants. Before reading any of the 98 held-out participants, save a signed or hashed freeze manifest containing:

- ROI centre coordinates and exact vertex supports;
- equivalence-group membership and representative-selection rule;
- regional lead-field basis and number of modes;
- preprocessing, epoch inclusion, spectral bins, and normalization;
- six-coefficient basis and coefficient directions;
- nuisance variables and their coding;
- classifier, penalties, tuning grid, and standardization;
- final K and every model coefficient;
- primary and secondary endpoints;
- missing-data and exclusion rules; and
- all planned region-level and negative-control tests.

No threshold, coordinate, coefficient, or endpoint may be altered after validation outcomes are viewed.

## 8. Confirmation in the 98 held-out participants

### 8.1 Primary test

Apply the frozen demographic and combined models without refitting. The primary confirmation endpoint is improvement in log loss for the combined model relative to the frozen demographics-only model. Report the effect estimate and its uncertainty as well as the prespecified inferential test.

### 8.2 Secondary predictive reporting

Report AUC, Brier score, balanced accuracy, sensitivity, specificity, calibration intercept, and calibration slope. These are supportive unless promoted to primary status before the freeze.

### 8.3 Regional confirmation

For each frozen ROI, test its six spectral coefficients jointly in one multivariate regional test. Apply Holm correction across the frozen ROIs. Inspect individual spectral components only after the corresponding regional test and label them exploratory.

### 8.4 Negative controls and sensitivity analyses

Evaluate diagnosis prediction from QC variables alone, trial count and condition availability, posterior variance or inverse-quality measures, age and sex prediction from neural features, EC-only and EO-only repetitions, sensitivity to temporal and ocular channels, sensor-level spectral/topographic confirmation, and batch/site effects where available. Medication and symptom-severity analyses remain sensitivity analyses if those variables are sufficiently complete.

## 9. Interpretation of the permutation result

The completed 1,000-permutation analysis tested the null hypothesis that, conditional on the permutation blocks, diagnosis labels carry no additional relationship to the entire neural search pipeline. Because feature selection and tuning were repeated under each label permutation, it protects against the 452-patch search and supports the observed search-level incremental signal.

It does **not** provide a p-value for a particular frozen ROI set and does not prove that one shortlist is uniquely optimal. If Paper 1 requires a discovery-stage p-value for the final peer-set selection rule, the complete consensus, equivalence grouping, K selection, and pruning procedure must be repeated inside every permutation. The independent 98-participant confirmation is the cleaner primary test of the final fixed set.

## 10. Claim boundary

If confirmation succeeds, Paper 1 may claim that a prespecified set of Bayesian-inversion-derived regional features generalizes to held-out participants and adds diagnosis-related information beyond demographics, at the spatial precision supported by lead-field equivalence.

It may not claim that the regions cause MDD, that the reconstructed power is an absolute physiological amplitude, or that effective connectivity has been established. Causal and directed-connectivity claims require the separately specified DCM/PEB analysis in Paper 2.

## 11. Required outputs before validation is unlocked

- outer-fold peer-set performance table for K = 1–6;
- candidate and equivalence-group stability table;
- leave-one-region-out and substitution sensitivity table;
- lead-field identifiability report;
- final discovery-only ROI map and coordinates;
- machine-readable freeze manifest with hash;
- validation analysis script that reads, but does not modify, the manifest; and
- a signed decision log confirming that validation access remains zero until all preceding files exist.
