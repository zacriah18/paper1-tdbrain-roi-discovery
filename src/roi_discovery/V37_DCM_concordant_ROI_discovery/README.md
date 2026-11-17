# V37: DCM-concordant supervised ROI discovery

V37 is a versioned replacement for the diagnosis-blind biological ranking
used in V34. It preserves the existing inversions and split, reconstructs
SPM's exact 16 mm `IMG` region at every cortex-covering centre, extracts
participant-level spectral landscapes, and performs nested supervised ROI
selection using neural features only.

## Run order

1. `01_exact_IMG_patches/A01_build_exact_IMG_patch_universe_V37.m`
2. `02_node_features/A02_extract_DCM_concordant_node_features_V37.m`
3. `03_participant_features/A03_assemble_participant_spectral_landscapes_V37.m`
4. `04_supervised_discovery/A04_run_nested_supervised_discovery_V37.m`
5. `04_supervised_discovery/A04b_run_full_pipeline_permutations_V37.m`
6. `04_supervised_discovery/A04c_run_paired_EC_EO_discovery_V37.m`
7. `05_shortlist/A05_freeze_spatial_shortlist_V37.m`
8. `06_relationship_screen/A06_extract_shortlist_directed_dependence_V37.m`

`run_long_V37.ps1` runs extraction, participant assembly, the primary and
paired nested analyses, and shortlist freezing. Full-pipeline permutations
and the relationship screen are intentionally separate expensive jobs.

The 98 validation participants are not used by these scripts.

For a bounded extraction smoke test:

```powershell
$env:TDBRAIN_V37_MAX_RECORDINGS='1'
& 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' -batch "run('...A02_extract_DCM_concordant_node_features_V37.m')"
```

Delete or change only the environment override before the full run. The
scientific defaults in `v37_config.m` remain frozen.
