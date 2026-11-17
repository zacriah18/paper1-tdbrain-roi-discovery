# V35: DCM-aligned patch identifiability and network audit

V35 follows the frozen diagnosis-blind V34 set of twelve connected geodesic 16 mm patches.

Run order:

1. `01_identifiability/A01_audit_patch_identifiability_V35.m`
2. `02_connectivity/A02_extract_patch_connectivity_V35.m`
3. `03_summary/A03_summarize_network_audit_V35.m`
4. `04_dcm_handoff/A04_build_identifiable_DCM_handoff_V35.m`

The frozen interpretation rules are in `A00_INTERPRETATION_LOCK.md`.

The primary output is the pairwise source-model identifiability audit. Each audit signal is the maximally inverse-observable combination within the first six regional lead-field modes, not an average of patch vertices. The connectivity outputs are descriptive checks on these virtual-node signals. The time-reversed, instantaneously whitened Granger calculation is deliberately labelled a sensitivity analysis and cannot support a causal claim. Cross-spectral DCM remains the proposed effective-connectivity handoff.

All computations use discovery recordings only. Neither group separation nor connectivity is used to select the V34 nodes. Validation participants remain untouched.

The A04 handoff exhaustively chooses a feasible four-to-six-node subset with no pairwise V35 confusability warning, prioritizing the frozen diagnosis-blind V34 candidate ranks. It remains provisional until cross-spectral DCM model comparison and validation.

## Completed discovery result

- 424 discovery recordings entered the operator audit; all had algebraic rank 12, but the median effective rank was 6.00 and 13/66 node pairs triggered a confusability warning.
- 422/424 recordings produced complete twelve-node virtual signals and 27,852 recording-pair rows.
- Two MDD recordings were excluded only from the complete virtual-signal audit because their saved inverse operators contained all-zero blocks for one or more candidate patches. Their 28–29 good sensor epochs remain available for future sensor-level DCM.
- The largest discovery-only edge descriptions were modest and unadjusted (maximum absolute Cohen d 0.487; maximum orientation-free AUC among the ten largest effects 0.650). No edge metric was used for selection.
- No Granger direction was cohort-stable: maximum population sign consistency was 0.630 and maximum joint time-reversal/whitening pass rate was 0.604.
- The provisional handoff contains six mutually non-confusable nodes and excludes all class/connectivity metrics from selection.
