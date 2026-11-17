# V37 method and analysis lock

Date frozen: 4 August 2026

## Purpose

V37 is the primary Paper 1 discovery analysis. It asks which technically
estimable cortical regions show reproducible MDD-versus-HC differences in
spectral phenomena that the planned cross-spectral DCM could plausibly
explain.

The source-derived features are **DCM-concordant**, not literal inputs to
DCM. First-level CSD-DCM will later fit sensor-level cross-spectra using the
forward model, frozen ROI coordinates, neuronal model and connectivity
hypotheses.

## Immutable separation of roles

1. Neural discovery variables may select ROIs: regional 4--45 Hz spectral
   shape, regional spectral level, signed EC/EO spectral modulation, and
   shortlist-only regional dependence metrics.
2. Technical variables may only establish estimability: data coverage,
   regional mode rank, inverse-filter norm, posterior uncertainty,
   split-half reliability, overlap and lead-field subspace ambiguity.
3. Age, sex, recording quality and batch variables are nuisance controls.
   They may balance folds, define demographic benchmarks, support adjusted
   sensitivity analyses, and enter Paper 2 PEB. They cannot select an ROI.
4. Anatomy and MDD literature are applied after the data-driven shortlist
   is frozen. They assess plausibility and cannot rescue a failed candidate.

## Cohort lock

- The 225-participant V32 discovery set is used for all feature definition,
  tuning, candidate selection and Paper 1 cross-validation.
- The 98-participant validation set is not read by V37.
- All recordings and conditions belonging to one participant remain in the
  same cross-validation fold.

## Spatial lock

Candidate centres are inherited only as a cortex-covering grid from V34.
V34's diagnosis-blind candidate ranking is discarded.

For every centre, V37 reproduces SPM `IMG` construction exactly:

```matlab
Dp = sum((vertices - coordinate).^2, 2);
Ip = find(Dp < 16^2);
U  = spm_svd(lead_field(:,Ip)', 0);
U  = U(:,1:6);
G  = lead_field(:,Ip) * U;
```

If fewer than six vertices fall inside the sphere, SPM's six-nearest-vertex
fallback is used. No geodesic substitution is made.

## Primary participant representation

The Bayesian inverse operator is applied to every good epoch. Each exact
regional basis is projected through that participant's inverse operator.
Regional spectra are estimated from two-second windows over 4--45 Hz and
averaged over all six modes, epochs and available resting conditions.

The primary source-landscape representation subtracts, within participant
and frequency, the median across technically eligible patches. This makes
selection depend on relative spatial spectral expression rather than an
arbitrary subject-wide inverse scale. The complete spectral curve is
represented by six fixed cosine-basis coefficients per patch; the basis is
defined without diagnosis labels or cohort fitting.

Signed EC-minus-EO spectra form a separate paired-condition analysis. They
are not mixed with the primary all-participant model when a condition is
missing.

## Supervised discovery lock

- Sparse-group logistic regression groups the six spectral coefficients of
  each patch.
- Scaling, imputation, hyperparameter tuning and selection are repeated
  within the training portion of every outer fold.
- Outer folds are balanced using diagnosis, age band and sex. Age and sex
  are not columns of the neural selection matrix.
- Selection stability, out-of-fold discrimination, calibration and full
  participant-label permutations are reported.
- Age/sex-only performance is a benchmark, not an ROI-selection component.

The method is intentionally diagnosis-informed inside the discovery set.
It cannot guarantee discrimination. A null or unstable result remains an
allowed outcome.

## Network and causal-language lock

Only a stable spatial shortlist is eligible for pairwise analysis.
Imaginary coherence, wPLI, phase-slope index and time-reversal-tested
Granger measures are hypothesis-generating directed-dependence metrics.
They are not neuronal causality and cannot validate an ROI.

Paper 1 freezes alternative identifiable 4--6-node model families. Paper 2
tests effective connectivity with CSD-DCM, BMR/BMA and PEB. Independent
participants, not DCM alone, provide validation.

## Superseded interpretation

- V34 remains a diagnosis-blind technical-reference analysis.
- V35 remains a virtual-source connectivity and identifiability prototype.
- V36 remains a six-node CSD-DCM feasibility pilot.

None of their provisional ROI rankings defines the V37 shortlist.
