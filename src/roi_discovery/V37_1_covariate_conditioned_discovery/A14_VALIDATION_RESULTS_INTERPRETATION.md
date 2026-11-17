# V37.1 Frozen Validation Results and Interpretation

**Completed:** 8 August 2026  
**Validation data:** 98 participants, 186 recordings  
**Extraction failures:** 0  
**Claim tier:** internal held-out V37.1 confirmation; not untouched external validation because the same participant split was used previously in V32.

## 1. Primary frozen result

The prespecified primary model contained patch 385 only, centred at `[21.0443, -96.4770, -17.5839]` mm in right posterior occipital cortex.

| Metric | Demographics | Primary K=1 | Increment |
|---|---:|---:|---:|
| AUC | 0.650 | 0.682 | +0.032 |
| Log loss | 0.6602 | 0.6495 | +0.0107 improvement |
| Brier score | 0.2340 | 0.2280 | −0.0060 |
| Balanced accuracy | 0.622 | 0.653 | +0.031 |
| Calibration slope | 0.775 | 0.715 | — |

- Conditional fixed-model permutation: `p = 0.0193`.
- Null support: 14 conditional blocks, 11 mixed-label blocks, and 95/98 participants in mixed-label blocks.
- Participant-bootstrap 95% interval for incremental log loss: `−0.0403 to +0.0565`.
- Participant-bootstrap 95% interval for incremental AUC: `−0.0454 to +0.1115`.

The result meets the prespecified conditional permutation criterion, but the estimated improvement is small and its participant-bootstrap interval includes zero. It is evidence of a reproducible frozen prediction direction, not evidence of a precisely estimated clinical effect size.

## 2. Secondary four-region DCM-sized family

The secondary family contained patches 385, 5, 261, and 314.

| Metric | Demographics | Secondary K=4 | Increment |
|---|---:|---:|---:|
| AUC | 0.650 | 0.706 | +0.056 |
| Log loss | 0.6602 | 0.6195 | +0.0407 improvement |
| Brier score | 0.2340 | 0.2174 | −0.0165 |
| Balanced accuracy | 0.622 | 0.612 | −0.010 |
| Calibration slope | 0.775 | 0.815 | — |

- Conditional fixed-model permutation: `p = 0.000400` with 3/10,000 null values meeting or exceeding the observed statistic.
- Participant-bootstrap 95% interval for incremental log loss: `−0.0254 to +0.1052`.
- Participant-bootstrap 95% interval for incremental AUC: `−0.0508 to +0.1614`.

The four-region family provides stronger probability ranking and log-loss performance than the primary one-region model, but it was frozen as secondary. It cannot replace the primary model after validation. Its balanced accuracy is not improved at the default threshold, showing why threshold-free and calibration-sensitive metrics are more informative here than one arbitrary classification cut-off.

## 3. Hierarchical regional tests

One six-component multivariate omnibus test was performed per frozen DCM ROI, followed by Holm correction across four regions.

| Patch | Approximate anatomy | Omnibus p | Holm p | Frozen-direction p | Direction Holm p |
|---:|---|---:|---:|---:|---:|
| 385 | right occipital pole / occipital fusiform / lingual | 0.467 | 0.467 | 0.0193 | 0.0579 |
| 5 | left transverse temporal / planum polare / posterior insula | 0.0496 | 0.149 | 0.278 | 0.278 |
| 261 | right entorhinal / parahippocampal / ventral temporal | 0.00720 | **0.0288** | 0.00260 | **0.0104** |
| 314 | right precuneus / posterior cingulate | 0.176 | 0.351 | 0.136 | 0.272 |

Patch 261 is the only region with a Holm-confirmed six-component group difference. Patch 385 confirms the prespecified classifier direction without showing a broad six-component omnibus difference. These are different hypotheses: the frozen direction is a one-dimensional discovery-trained contrast, whereas the omnibus test pays a six-dimensional penalty and asks whether any regional spectral component differs.

## 4. EC/EO sensitivity

The frozen models were applied separately to participant-relative EC and EO landscapes. These analyses are sensitivity checks because the classifier was trained on the condition-average representation.

| Condition | Model | N | AUC | Incremental log loss | Conditional p |
|---|---|---:|---:|---:|---:|
| EC | primary K=1 | 96 | 0.646 | −0.0032 | 0.0455 |
| EC | secondary K=4 | 96 | 0.667 | −0.0061 | 0.00460 |
| EO | primary K=1 | 90 | 0.693 | +0.0113 | 0.0519 |
| EO | secondary K=4 | 90 | 0.722 | +0.0410 | 0.00100 |

A positive conditional-permutation result does not rescue a negative observed log-loss increment. In EC alone, neither frozen model improves probability prediction over demographics. The positive average-condition result is therefore driven mainly by EO. This may represent condition-dependent MDD physiology, but it may also reflect vigilance, visual-system state, ocular contamination, or other EC/EO acquisition differences. That ambiguity must be resolved before a strong biological or mechanistic claim.

## 5. QC sensitivity

At patch 385, none of five technical variables differed between groups after Holm correction:

- split-half spectral reliability;
- regional mode rank;
- filter norm;
- posterior variance; or
- mean good-epoch count.

Mean good-epoch count showed the strongest uncorrected tendency (`p = 0.0624`), but its Holm-adjusted p-value was 0.312. The measured QC variables therefore do not explain the frozen regional score, although they cannot exclude unmeasured vigilance or residual ocular effects.

## 6. Defensible Paper 1 conclusion

The results support the following statement:

> A frozen Bayesian-inversion-derived regional model generalized to the V37.1 held-out cohort and improved conditional MDD/HC probability prediction beyond demographics. A prespecified four-region family showed stronger global prediction, with the right entorhinal/parahippocampal patch providing the clearest region-level confirmation. Effects were imprecisely estimated and concentrated in eyes-open data, limiting mechanistic interpretation.

The results do not establish:

- a clinically deployable diagnostic biomarker;
- external generalization to a new acquisition cohort;
- that patch 385 or patch 261 causes MDD;
- that all four regions are independently necessary; or
- directed effective connectivity.

## 7. Required next steps

1. Complete sensor-space confirmation focused on EO and posterior/ventral temporal topographies.
2. Audit ocular and temporal channel sensitivity and any available vigilance markers.
3. Preserve all four frozen nodes for the first Paper 2 DCM family; do not delete nodes based on these validation outcomes.
4. Complete subject-level CSD sensitivity and joint observability audits before DCM inversion.
5. Compare prespecified four-node connectivity families using DCM model evidence, followed by PEB/BMR and out-of-sample prediction.
6. Seek a genuinely external cohort for final biomarker replication.

## 8. Result files

- `A11_frozen_validation_performance.csv`
- `A11_frozen_validation_predictions.csv`
- `A11b_validation_uncertainty.csv`
- `A12_hierarchical_region_tests.csv`
- `A13_EC_EO_frozen_model_sensitivity.csv`
- `A13_primary_patch_QC_sensitivity.csv`
