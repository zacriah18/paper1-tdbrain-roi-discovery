# Repository context

Status as of 17 November 2026: curated local source snapshot prepared; Git initialization and remote publication are pending. Start with README.md and docs/provenance.md. The working analysis folders under `C:\MATLAB` remain the source locations; `manifests/source_snapshot.csv` maps every copied file and checksum.

Authoritative modules: `src/preprocessing/` (A-E), `src/roi_discovery/V37_DCM_concordant_ROI_discovery/`, `src/roi_discovery/V37_1_covariate_conditioned_discovery/`, and inherited V32-V36 code under `src/inherited/`. The included source is not yet portable; machine-specific paths remain. The next concrete step is to verify the source manifest and review configuration sensitivity, then initialize Git and create a private GitHub remote after the code boundary is accepted.
