# EO sensor and ocular-proxy audit

Completed on 8 August 2026 using 90 held-out participants with usable eyes-open recordings.

## Result

- Twenty-six EEG channels were tested with the same six-component 4–45 Hz spectral basis used by the source-patch pipeline.
- Group statistics were conditioned by age band, sex, and condition availability using 10,000 within-block label permutations.
- No sensor channel survived Holm correction across the 26 tests. The smallest corrected value was 0.239 (F8).
- Neither frontal-polar proxy was close to corrected significance: Fp1 and Fp2 both had Holm p = 1.
- The frozen patch-385 EO spectral score had very small correlations with Fp1 (rho = -0.052) and Fp2 (rho = -0.026).
- Its strongest sensor correlations were posterior and anatomically concordant with the right-occipital patch: O1 rho = 0.460, Oz rho = 0.450, and O2 rho = 0.393; all three survived Holm correction for the descriptive channel correlations.

## Interpretation

This audit does not show evidence that the validated EO patch-385 signal is simply a frontal-polar EEG effect. Its strongest sensor-space correspondence is occipital, which supports the spatial interpretation of the frozen posterior ROI.

This is a reassuring negative control, not proof that ocular contamination is absent. The inversion-visible datasets contain no dedicated vertical or horizontal EOG channels, and Fp1/Fp2 cannot fully reproduce an EOG-based artifact analysis. The DCM handoff should therefore retain an ocular-sensitivity caveat and, where possible, repeat estimation after stricter frontal-epoch rejection or with raw EOG-derived nuisance measures.

The audit did not alter ROI identities, coordinates, supports, or ranking.
