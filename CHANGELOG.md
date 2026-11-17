# Changelog

## 2026-11-17 - Initial curated source snapshot

Staged a code-only snapshot of preprocessing/source inversion stages A-E, V37/V37.1 ROI discovery, and inherited V32-V36 source/configuration code. Added provenance, data boundary, dependency and local repository guidance plus a SHA-256 source manifest. Source files were copied without edits; original analysis folders remain untouched. Excluded raw/participant data, outputs, caches, installed toolboxes and Stage F/G downstream DCM/PEB. Validation performed: selected-file count and source-to-copy checksums are to be recorded before commit. No MATLAB analysis or tests were run. Remaining: inspect boundary/config files, complete transitive dependency and path-order audit, portability refactor, version/license review, then decide on GitHub private repository push.
