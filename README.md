# Paper 1 TDBRAIN ROI discovery pipeline

## Purpose and pipeline role

This private code repository collects the preprocessing and SPM source-inversion stages that produce the whole-cortex inputs, followed by the V37 and V37.1 Paper 1 regional discovery workflows. It is a curated source snapshot from the working analysis tree; the original folders remain the research source of record.

```text
TDBRAIN data + locked cohort decisions
  -> A-B inventory and shortlist
  -> C-D preprocessing and artifact rejection
  -> E SPM source inversion and source QC
  -> V37 exact IMG patches and supervised discovery
  -> V37.1 conditional discovery, nulls, controls and later confirmation
```

Stage E estimates cortical source activity. Stages F/G in the dataset folder are downstream ROI-based DCM/PEB and are outside this repository's initial scope. They can be added later as a distinct module after a separate dependency and data-access review.

## Start here

- [`docs/provenance.md`](docs/provenance.md): source boundaries and snapshot limitations.
- [`docs/data_access.md`](docs/data_access.md): required protected inputs and exclusions.
- [`environment/matlab_dependencies.md`](environment/matlab_dependencies.md): software requirements and current portability status.
- [`src/preprocessing/`](src/preprocessing/): stages A-E and non-participant channel/montage configuration.
- [`src/roi_discovery/V37_DCM_concordant_ROI_discovery/README.md`](src/roi_discovery/V37_DCM_concordant_ROI_discovery/README.md): V37 run order and scope.
- [`src/roi_discovery/V37_1_covariate_conditioned_discovery/README.md`](src/roi_discovery/V37_1_covariate_conditioned_discovery/README.md): V37.1 run order, guards and claim boundaries.
- [`manifests/source_snapshot.csv`](manifests/source_snapshot.csv): original relative path, destination, SHA-256 and file role for every copied file.

## Status and evidence date

Snapshot staged 17 November 2026 and pushed to GitHub on 18 November 2026. It contains 186 selected MATLAB, PowerShell and Markdown files plus the source manifest. The source manifest records file hashes; it does not establish analytical correctness, exact data availability or successful reruns. No analysis or test was run while preparing this repository.

## Decisions and constraints

- Keep raw recordings, participant-level tables, source inversions, model outputs, caches and generated derivatives out of Git.
- Preserve source files and scientific locks in this snapshot; do not edit the original working analysis trees through this repository setup.
- V37/V37.1 currently set up MATLAB paths that include V32-V36 and inherit earlier configuration. Those legacy code branches are therefore included as inherited source, while their old data/results are excluded.
- The copied configuration still contains historical machine-specific absolute paths. A reviewed portability change is needed before this repository can be run from a new checkout.
- No license is declared yet. Confirm code ownership and redistribution terms before reuse or further distribution.
- Validation access guards and locked cohort/split definitions are scientific constraints. Preserve them during portability work.

## Open work

1. Review the selected code/configuration snapshot and its source manifest.
2. Trace transitive MATLAB calls, path ordering, shell runners and required non-data inputs; resolve inherited helper collisions.
3. Refactor only the repository copy to use one local path configuration, retaining frozen scientific defaults and documenting each change.
4. Add version and setup instructions for MATLAB, SPM12 and FieldTrip; confirm any licensing constraints.
5. Review protected-data boundaries and repository visibility, then use a bounded synthetic or single-recording setup check after review.

## Related work

- [Working Paper 1 analysis tree](../2026%20TDBRAIN%20V31%20source%20ROI%20discovery/README.md) remains the historical source location.
- [TDBRAIN dataset pipeline](../2026%20TDBRAIN%20dataset/README.md) owns upstream preprocessing and source inversion code.
- [Paper 2 DCM workspace](../2026%20TDBRAIN%20V31%20dcm%20from%20data%20informed%20roi/README.md) owns downstream ROI-based DCM/PEB.

## Recent changes

See [`CHANGELOG.md`](CHANGELOG.md) and [`CITATION.cff`](CITATION.cff). The initial v0.1.0 release notes are in [`docs/release-notes-v0.1.0.md`](docs/release-notes-v0.1.0.md).
