# V37.1 covariate-conditioned analysis and validation lock

Date frozen: 4 August 2026

## Purpose

V37.1 tests whether DCM-concordant source-spectral features add held-out
MDD/HC information beyond prespecified nuisance variables. V37 remains an
unchanged supervised discovery record.

## Cohort boundary

- Only the 225 V32 `discovery` participants may be read.
- The 98 V32 `validation` participants are a fixed final validation cohort.
- Validation participants cannot define folds, scaling, features, penalties,
  coordinates, directions, thresholds, model families or stopping rules.
- Rotating resampling is confined to the development cohort.

## Models on identical folds

1. Intercept/prevalence reference.
2. Demographic nuisance model: age, age squared, binary sex and paired
   condition availability.
3. QC-only negative-control model.
4. Neural-only sparse-group logistic model.
5. Neural-plus-nuisance sparse-group logistic model, with nuisance
   coefficients unpenalized.
6. Sensor-spectrum comparator on the same frequency range and folds.

ROI selection is calculated only from the neural patch coefficients of the
combined model. Nuisance coefficients can adjust the decision boundary but
cannot select a patch.

## Primary endpoint

```text
incremental log loss = demographic log loss - combined log loss
```

Positive values favour added neural information. Incremental AUC is
secondary. AUC, log loss, Brier score, balanced accuracy, sensitivity,
specificity, calibration intercept and calibration slope are reported.

## Fixed nested resampling

- Five outer folds repeated five times at participant level.
- Four fixed inner folds per outer training set.
- All models and permutations use the identical locked folds.
- Scaling, imputation, technical eligibility and penalty tuning use training
  participants only.

## Conditional permutation

Diagnosis labels are permuted only within exchangeability blocks formed by
age band, sex and EC/EO condition availability. Every valid permutation
repeats the complete nested neural-plus-nuisance fitting and selection
process. The primary permutation statistic is incremental log loss.

## Interpretation

V37.1 is still development-cohort inference. Its global conditional
permutation p-value calibrates the search procedure; it does not provide an
independent regional p-value. Selected-region effects remain descriptive
until the fixed validation cohort is accessed under a separate lock.
