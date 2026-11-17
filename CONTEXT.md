# Repository context

Status as of 17 November 2026: a local Git repository is initialized on branch `main`; initial curated snapshot commit `259ac19` is recorded. The private GitHub remote and push remain pending because GitHub API access is unavailable in the current execution shell. Start with README.md and docs/provenance.md. The working analysis folders under `C:\MATLAB` remain the source locations; `manifests/source_snapshot.csv` maps every copied file and checksum.

Authoritative modules: `src/preprocessing/` (A-E), `src/roi_discovery/V37_DCM_concordant_ROI_discovery/`, `src/roi_discovery/V37_1_covariate_conditioned_discovery/`, and inherited V32-V36 code under `src/inherited/`. The included source is not yet portable; machine-specific paths remain. The next concrete step is to create the private remote and push `main`, then complete the transitive dependency/path audit and portability refactor in a later commit.
