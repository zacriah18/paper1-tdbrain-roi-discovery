function cfg = v37_config()
%V37_CONFIG Frozen configuration for DCM-concordant supervised ROI discovery.

v36_root = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V36_six_node_csd_dcm';
addpath(fullfile(v36_root, '00_config'));
cfg = v36_config();

cfg.pipeline_version = 'V37_DCM_concordant_ROI_discovery_0.1.0';
cfg.v36_root = v36_root;
cfg.output_root = fullfile(cfg.project_root, 'derivatives', ...
    'V37_DCM_concordant_ROI_discovery');

% The source-space region exactly reproduces SPM's IMG rule.
cfg.patch_radius_mm = 16;
cfg.regional_spatial_modes = 6;
cfg.frequency_hz = 4:45;
cfg.connectivity_frequency_hz = [4 45];
cfg.spectral_basis_count = 6;
cfg.spectral_window_seconds = 2;
cfg.minimum_good_epochs = 10;
cfg.resume = true;

% Diagnosis-blind technical eligibility only. No activity percentile gate.
cfg.minimum_participant_coverage = 0.90;
cfg.minimum_median_split_half_spectral_correlation = 0.50;
cfg.minimum_median_regional_mode_rank = 6;
cfg.minimum_filter_norm = 1e-12;

% Supervised discovery is confined to the frozen discovery cohort.
cfg.outer_folds = 5;
cfg.outer_repeats = 5;
cfg.inner_folds = 4;
cfg.sparse_group_alpha = [0.00 0.25 0.50 0.75];
cfg.lambda_fraction = [1.00 0.50 0.20 0.10 0.05 0.02];
cfg.optim_max_iterations = 500;
cfg.optim_tolerance = 1e-6;
cfg.selection_coefficient_tolerance = 1e-7;
cfg.random_seed = 4082026;

% Stability and identifiability guide the shortlist; diagnosis-blind rank
% is not used as a biological selection score.
cfg.shortlist_max_nodes = 30;
cfg.dcm_family_min_nodes = 4;
cfg.dcm_family_max_nodes = 6;
cfg.minimum_outer_selection_frequency = 0.50;
cfg.redundancy_subspace_rms_correlation = 0.80;
cfg.redundancy_coordinate_distance_mm = 16;

% Full-pipeline participant-label permutation. The default is suitable for
% the final run and can be reduced explicitly for smoke testing.
cfg.permutation_count = 1000;

% Bounded-run overrides. These never alter the frozen scientific defaults.
cfg.max_recordings = Inf;
v = str2double(getenv('TDBRAIN_V37_MAX_RECORDINGS'));
if isfinite(v) && v > 0, cfg.max_recordings = round(v); end
v = str2double(getenv('TDBRAIN_V37_OUTER_REPEATS'));
if isfinite(v) && v > 0, cfg.outer_repeats = round(v); end
v = str2double(getenv('TDBRAIN_V37_PERMUTATIONS'));
if isfinite(v) && v >= 0, cfg.permutation_count = round(v); end
end
