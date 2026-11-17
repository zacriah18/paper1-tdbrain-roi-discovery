# MATLAB dependencies and setup status

## Required software

- MATLAB (exact version used for this source snapshot has not yet been verified).
- SPM12 with EEG support.
- FieldTrip version/build required by the SPM installation.
- MATLAB toolboxes/functions used by the analysis scripts (to be inventoried from the transitive call graph).
- Windows PowerShell for the supplied `.ps1` runners; MATLAB batch support for automated runs.

Do not copy vendor toolboxes into this repository. Install them under their own terms and record exact version/commit and licensing details here after verification.

## Current limitation

The copied code still contains machine-specific absolute paths and was not run. V37 inherits its configuration from V36, and V37/V37.1 add the V32-V36 roots to the MATLAB path. A portability refactor and dependency-call audit are required before a new checkout can be considered runnable.

## Planned local configuration

A future `local_paths.example.m` should define the repository root, protected dataset root, SPM root, and permitted output root. A user-local `local_paths.m` should be ignored by Git. Scientific values, cohort locks, seeds and access guards must remain unchanged unless a separately reviewed scientific change is intended.
