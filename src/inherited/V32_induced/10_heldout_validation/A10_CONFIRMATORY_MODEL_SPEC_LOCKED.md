# Held-out confirmatory model specification

This specification was written after the V2 support-band family was frozen and
before validation effect estimates were calculated.

Population: participants assigned to `validation` in the locked participant
split. Participants with one or both resting conditions are retained.

Primary outcome: mean within-recording percentile-normalized log induced
source energy within each frozen support.

For each of the eight frozen V2 support-band candidates:

```text
outcome ~ diagnosis * condition + age + sex + retained_good_epochs
          + inverse_VE + (1 | participant)
```

Reference levels are HC and restEC. The two primary coefficients per candidate
are the MDD diagnosis coefficient and the MDD-by-restEO interaction. The
confirmatory family therefore contains 16 tests. Holm's sequential procedure
controls family-wise error at alpha 0.05 over all 16 tests.

No candidate, model term, covariate or multiplicity rule will be changed after
examining validation estimates. Results are association estimates in this
dataset, not diagnostic biomarkers.
