# V34 DCM-aligned local-patch investigation

V34 tiles the canonical cortex with overlapping, connected 16 mm geodesic
patches so the investigatory spatial object matches the intended scale of a
standard local DCM source basis.

## Completed pipeline

1. The covered cortical mesh was tiled with 452 deterministic local patches.
   Every included cortical vertex is covered; median overlap is two patches per
   vertex.
2. Broadband spatial and single-epoch metrics were calculated for 610
   recordings, producing 275,720 recording-patch rows.
3. Resolution profiles were averaged over 424 discovery recordings without
   using diagnosis.
4. Six diagnosis-blind investigatory dimensions were computed: typical energy,
   upper-tail energy, spatial peak prominence, epoch fluctuation, temporal
   burst prominence and absolute EC/EO modulation.
5. Fifty-five patches met the frozen multi-criterion, precision, reliability
   and isolation gates. Profile-cosine and 30 mm coordinate pruning retained
   12 possible ROI candidates.
6. MDD/HC metrics were calculated separately and were not used for eligibility,
   ranking or pruning.

## Candidate interpretation

The 12 candidates span medial frontal/anterior cingulate, medial orbitofrontal,
inferior frontal/anterior insular, middle frontal, inferior temporal/fusiform,
angular/occipital, postcentral and other local supports. Each contains 21-44
mesh vertices and is explicitly centred on a 16 mm geodesic patch.

These candidates indicate locations with multiple desirable investigatory
properties in the reconstructed broadband data. They are not time-locked
activations, statistically significant regions, proven generators or MDD
biomarkers.

## Preliminary class description

Across all 452 patches, participant-level five-fold out-of-fold AUC for a
patch feature plus age and sex ranged from 0.557 to 0.699. Age and sex alone
gave AUC 0.597. Median incremental AUC was 0.003 and the maximum was 0.102.
These values are descriptive discovery metrics only and do not validate class
distinguishability. The candidate file explicitly records that class metrics
were not used for selection.

## Primary outputs

- `01_patch_tiling/A01_DCM_aligned_16mm_patch_centres.csv`
- `02_patch_metrics/A02_DCM_aligned_patch_metrics.csv`
- `03_candidates/A03_patch_investigatory_metrics_ALL.csv`
- `03_candidates/A03_DCM_aligned_possible_ROI_candidates.csv`
- `03_candidates/A03_MDD_HC_class_description_NOT_SELECTION.csv`
