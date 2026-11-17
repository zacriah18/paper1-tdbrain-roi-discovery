# V36 six-node cross-spectral DCM hypothesis lock

## Scope

V36 fits discovery recordings only. The six coordinates are re-audited using SPM's exact `IMG` operator before inversion. No six-node set containing the focal ROI has zero exact subspace warnings, so selection minimizes the number of exact DCM warnings first, then the number of earlier V35 inverse-operator warnings, and finally the summed diagnosis-blind V34 ranks. The residual warning is reported as an identifiability limitation, not hidden. Class separation and V35 functional-connectivity/Granger values are not used to choose nodes or edges. Validation participants remain untouched.

The focal node is the highest diagnosis-blind V34 contributor retained in the identifiable handoff: left medial superior frontal cortex (`L_mSFG`, V34 rank 2). “Focal” means it anchors one nested connectivity family; it does not mean that it is causal, disease-specific, or a proven point source.

## Observation and neuronal models

- Analysis: SPM DCM for cross-spectral densities (`CSD`).
- Spatial model: distributed imaging (`IMG`). SPM constructs a 16 mm Euclidean neighbourhood around each coordinate and retains six regional lead-field modes.
- Sensor modes: eight lead-field eigenmodes.
- Neuronal model: canonical microcircuit (`CMC`) at every node.
- Populations per node: spiny stellate cells, superficial pyramidal cells, inhibitory interneurons, and deep pyramidal cells.
- Forward pathways originate from superficial pyramidal populations and target granular/deep populations; backward pathways originate from deep pyramidal populations and target superficial pyramidal/inhibitory populations, following the installed SPM equations.
- Data window: 0–3992 ms from every good four-second rest epoch.
- Frequency window: 4–45 Hz in 1 Hz steps. Four hertz is the SPM CSD default lower bound for these data and avoids making the least stationary drift/delta range primary. A 1–45 Hz rerun is a later sensitivity analysis, not a model selected after viewing group effects.
- No experimental input and no within-recording modulatory `B` matrix, because each source file contains one rest condition. EC and EO are inverted separately and combined only in a repeated-measures higher-level analysis.

## Hierarchy

Within each hemisphere, posterior angular/occipital association cortex is placed below inferior/middle temporal cortex, which is placed below frontal cortex. This defines the laminar forward/backward labels; it is a model hypothesis, not a claim that anatomical hierarchy has been measured in these participants.

## Nested hypothesis family

1. `H1_BILATERAL_SERIAL`: posterior → temporal → frontal feedforward pathways with reciprocal feedback.
2. `H2_SERIAL_PLUS_DORSAL`: H1 plus direct posterior ↔ frontal pathways within hemisphere.
3. `H3_SERIAL_PLUS_CALLOSAL`: H1 plus reciprocal dual-laminar homologous frontal, temporal, and parietal pathways.
4. `H4_DORSAL_CALLOSAL`: H1 plus dorsal and homologous pathways.
5. `H5_PARENT_FOCAL_HUB`: H4 plus right temporal/parietal association inputs to the focal left medial frontal node and reciprocal feedback.

Only H5 is inverted at first level. The smaller hypotheses are nested reductions for later PEB/Bayesian model reduction. This avoids repeatedly fitting models to the same recording and makes the focal-hub hypothesis directly testable against H4.

## Interpretation limits

The first-level parameters are conditional effective-connectivity estimates under this neuronal, spatial, spectral, and anatomical model. They are not Granger causality and cannot establish biological causation. Group claims require first-level QC, a participant-aware EC/EO hierarchy, PEB/model reduction or averaging, multiplicity control over the frozen parameter family, and confirmation in the untouched validation cohort.

## Method sources

- Installed implementation: `spm_dcm_csd.m`, `spm_dcm_csd_data.m`, `spm_dcm_erp_dipfit.m`, `spm_cmc_priors.m`, and `spm_fx_cmc.m` in local SPM 25.01.02.
- Friston et al. (2008), *Dynamic causal models of steady-state responses*.
- Bastos et al. (2012), *Canonical microcircuits for predictive coding*.
