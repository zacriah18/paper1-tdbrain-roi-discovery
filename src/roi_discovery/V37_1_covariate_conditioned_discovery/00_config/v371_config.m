function cfg = v371_config()
%V371_CONFIG Frozen configuration for covariate-conditioned confirmation.
v37_root = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V37_DCM_concordant_ROI_discovery';
addpath(fullfile(v37_root,'00_config'));
cfg = v37_config();
cfg.pipeline_version = 'V37_1_covariate_conditioned_discovery_0.1.0';
cfg.v37_root = v37_root;
cfg.output_root = fullfile(cfg.project_root,'derivatives', ...
    'V37_1_covariate_conditioned_discovery');

% Nuisance variables enter models without sparsity penalties and can never
% contribute to patch selection frequency.
cfg.nuisance_names = {'age','age_squared','sex_binary','paired_condition_available'};
cfg.conditional_permutation_blocks = {'age_band','sex','condition_availability'};
cfg.primary_statistic = 'incremental_log_loss_combined_vs_demographic';
cfg.secondary_statistic = 'incremental_AUC_combined_vs_demographic';
cfg.demographic_ridge = 1e-6;
cfg.qc_ridge = 1e-3;
cfg.permutation_count = 1000;
cfg.permutation_seed = 40820261;
cfg.permutation_checkpoint_every = 1;
cfg.solver_implementation = 'cached_vectorized_equivalent_1';
cfg.permutation_shard_start_index = 4; % permutations 1--3 are in the legacy checkpoint

% Sensor comparator uses the same frequency range, windows and fixed basis.
cfg.sensor_minimum_channel_coverage = 0.90;
cfg.sensor_grouping = 'EEG_channel';

% The V32 validation assignment is an explicit access boundary.
cfg.expected_discovery_participants = 225;
cfg.expected_validation_participants = 98;
cfg.validation_access_allowed = false;

% Discovery-only peer-set comparison. These settings implement the
% pre-validation lock in A00_PEER_SET_COMPARISON_AND_VALIDATION_PLAN.md.
cfg.peer_pipeline_version = 'V37_1_peer_set_comparison_0.1.0';
cfg.peer_set_sizes = 1:6;
cfg.peer_fixed_ridge_lambda = [100 10 1 0.1 0.01 0.001 0.0001 0];
cfg.peer_fixed_max_iterations = 100;
cfg.peer_fixed_tolerance = 1e-7;
cfg.peer_bootstrap_count = 2000;
cfg.peer_random_sets_per_fold = 20;
cfg.peer_random_seed = 8082026;
cfg.peer_joint_channel_modes = 8;
cfg.peer_v37_inner_stability_threshold = 0.50;
cfg.validation_fixed_permutation_count = 10000;
cfg.validation_fixed_permutation_seed = 80820261;

v = str2double(getenv('TDBRAIN_V371_OUTER_REPEATS'));
if isfinite(v)&&v>0, cfg.outer_repeats=round(v); end
v = str2double(getenv('TDBRAIN_V371_PERMUTATIONS'));
if isfinite(v)&&v>=0, cfg.permutation_count=round(v); end
end
