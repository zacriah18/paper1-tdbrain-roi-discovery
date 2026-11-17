# V35 interpretation lock: patch identifiability and network audit

## Purpose

V35 asks whether the 12 diagnosis-blind V34 candidates are distinguishable at the level of the saved forward/inverse operators, and whether their reconstructed signals show descriptive statistical dependence. It does not use connectivity or MDD/HC separation to select or replace the V34 nodes.

## What is a node here?

For every recording, the first six spatial eigenmodes of the regional lead field are formed from the vertices inside the frozen geodesic 16 mm patch. The audit virtual signal uses the fixed, diagnosis-blind linear combination inside that six-mode subspace that has maximal support under the saved inverse operator. This prevents an arbitrary first-mode choice from becoming a null virtual channel while retaining the local DCM basis. The signal is then reconstructed through the saved inverse temporal projector.

This virtual node signal is an audit representation. Cross-spectral DCM itself should be fitted to sensor cross-spectra with the frozen coordinates/patch priors; it should not treat these virtual signals as observed causal states.

## Frozen interpretation rules

1. Vertex overlap, centre distance, resolution-profile cosine, and regional lead-field subspace similarity quantify different failure modes. Spatial separation alone is insufficient.
2. Coherence is descriptive and zero-lag sensitive. Absolute imaginary coherency and wPLI are reported as leakage-resistant descriptive checks. Phase-slope index is directional only in a predictive phase-lag sense.
3. Granger values are a sensitivity analysis, not causal evidence. They are computed after anti-aliased resampling to 100 Hz with a fixed four-sample (40 ms) bivariate VAR order, repeated after symmetric instantaneous whitening, and checked after within-epoch time reversal.
4. No edge, direction, condition, group effect, or time interval is promoted as significant or used for candidate selection in V35.
5. A defensible effective-connectivity claim requires a specified DCM model space, model comparison or averaging, parameter-identifiability checks, and held-out confirmation.
6. A recording is excluded from the complete 12-node virtual-signal audit if any candidate patch has an all-zero saved inverse block. This does not imply that its raw sensor recording is unusable for sensor-level DCM.

## Primary decision

The main V35 decision is whether candidate patches must be merged, removed, or treated as mutually confusable before building the DCM model space. Network metrics are secondary descriptions used to propose plausible model families, not to establish causality.
