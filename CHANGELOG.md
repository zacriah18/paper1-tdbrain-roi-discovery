# Changelog

## 2026-11-17 - Initial curated source snapshot

Staged a code-only snapshot of preprocessing/source inversion stages A-E, V37/V37.1 ROI discovery, and inherited V32-V36 source/configuration code. Added provenance, data boundary, dependency and local repository guidance plus a SHA-256 source manifest. Source files were copied without edits; original analysis folders remain untouched. Excluded raw/participant data, outputs, caches, installed toolboxes and Stage F/G downstream DCM/PEB. Validation performed: all 186 manifest entries matched source SHA-256; no raw-data formats or credential-pattern matches were found; staged whitespace check reported pre-existing trailing spaces in preserved source/docs. Git initialized and the snapshot committed locally as `259ac19` on `main`. No MATLAB analysis or tests were run. Remaining: inspect configuration redistribution suitability, complete transitive dependency/path audit, portability refactor, version/license review, then create and push the private GitHub remote.

