# Data access and protected inputs

This repository contains code only; it does not grant access to the TDBRAIN dataset or participant-level data. Obtain approved access and store data in the approved protected location. Do not commit credentials, raw recordings, participant-level clinical tables, identifiable metadata, individual anatomical files, source inversions, model fits or generated derivatives.

The pipeline expects external inputs including the TDBRAIN recordings and participant/cohort tables; the locked shortlist and stage-specific output contracts; cleaned SPM EEG objects for source inversion; the SPM head model and required anatomical/forward-model assets; and generated source inversion objects consumed by V37/V37.1. Exact filenames and paths are specified in the source configs and must be documented in a future portable setup guide. Do not place a real participant manifest in this repository.

Use checksums or non-identifying aggregate manifests only where institutional policy permits. Keep local data paths in ignored machine-specific configuration, not in tracked files. Record required schema and expected output structure without identifying participant rows.
