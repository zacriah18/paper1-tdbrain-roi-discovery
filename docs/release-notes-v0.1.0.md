# v0.1.0 — Initial curated source snapshot

This pre-release packages the current Paper 1 pipeline source: preprocessing and SPM source reconstruction stages A-E; V37/V37.1 ROI discovery; and inherited V32-V36 source and configuration code. Raw EEG, participant-level data, source inversion outputs, derivatives, and downstream ROI-level DCM/PEB stages F/G are excluded.

## Status and limitations

- This is a curated source snapshot, not a clean-checkout reproducibility release.
- Machine-specific absolute paths remain in the copied code.
- The transitive dependency and MATLAB path-order audit is incomplete.
- No full analysis or clean-environment run was performed for this release.
- The included channel/montage configuration files and software ownership/redistribution terms need review before reuse or wider distribution.
- No license is declared in this release; reuse permissions are not yet specified.

Use `manifests/source_snapshot.csv` to map copied files to their original paths and SHA-256 hashes. See `docs/provenance.md` and `environment/matlab_dependencies.md` for the source boundaries and setup limitations.
