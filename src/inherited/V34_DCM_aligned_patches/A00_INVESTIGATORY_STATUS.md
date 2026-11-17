# Investigatory status and frozen metric definitions

The V34 objects are overlapping, connected 16 mm geodesic patches centred on
the canonical cortical mesh. This matches the intended spatial scale of an
ordinary local DCM source basis more closely than the broad V32 supports.

Selection is diagnosis-blind and does not use p-values, time-resolved
significance markers, MDD/HC effect sizes or classification performance.

Core investigatory dimensions are:

1. **Typical energy:** median across discovery recordings of patch-mean,
   within-recording percentile-normalized log broadband posterior energy.
2. **Upper-tail energy:** 90th percentile of that recording-level measure.
3. **Spatial peak prominence:** within-patch maximum minus mean log energy,
   summarised across recordings. This is concentration, not neuronal voltage.
4. **Epoch fluctuation:** median absolute deviation of log patch energy across
   good epochs, summarised across recordings.
5. **Temporal burst prominence:** maximum minus median epoch log energy,
   summarised across recordings.
6. **EC/EO modulation:** median absolute within-participant EC-minus-EO change.

Each dimension is percentile-ranked across patches. A possible ROI candidate
must be in the upper quartile on at least three dimensions, have split-half
reliability of at least 0.80, posterior precision at or above the patch median,
and acceptable resolution-profile isolation. Candidates are spatially pruned
to centres at least 30 mm apart. These rules define investigatory candidates,
not activated regions or biomarkers.

Separately reported class-description metrics are discovery-only Cohen's d,
out-of-fold AUC, balanced accuracy and incremental AUC over age/sex covariates.
They are excluded from candidate ranking and do not constitute validation.
