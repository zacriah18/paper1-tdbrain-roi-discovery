function cfg = v32_config()
%V32_CONFIG Frozen configuration for the Paper 1 induced-source pipeline.

cfg = struct();
cfg.pipeline_version = 'V32_induced_0.1.0';
cfg.project_root = 'C:\MATLAB\2026 TDBRAIN V31 source ROI discovery';
cfg.spm_dir = 'C:\MATLAB\spm';
cfg.inventory_csv = fullfile(cfg.project_root, 'derivatives', ...
    'A_inventory_source_inversions_V31', 'A_source_inversion_inventory.csv');
cfg.output_root = fullfile(cfg.project_root, 'derivatives', 'V32_induced');

cfg.inverse_index = 1;
cfg.require_inventory_status_ok = true;
cfg.minimum_good_epochs = 10;
cfg.expected_vertices = 8196;
cfg.store_as_single = true;
cfg.resume = true;

% SPM's induced contrast uses every integer frequency in fboi(1):fboi(2).
% Adjacent conventional bands therefore share their boundary frequency.
cfg.band_names = {'delta','theta','alpha','beta'};
cfg.band_limits_hz = [1 4; 4 8; 8 13; 13 30];
cfg.secondary_band_names = {'high_beta_low_gamma'};
cfg.secondary_band_limits_hz = [30 45];
cfg.include_secondary_bands = false;

% Empty means use the full time window saved with each inversion.
cfg.time_window_ms = [];
cfg.primary_normalization = 'within_recording_percentile_log_mean_energy';
cfg.log_floor = realmin('single');

% Equivalence-test recordings. More can be added without changing the
% cohort estimator. Test both conditions when they are available.
cfg.equivalence_subject_ids = {'sub-87958013'};
cfg.equivalence_conditions = {'restEC','restEO'};
cfg.equivalence_abs_tolerance = 1e-8;
cfg.equivalence_rel_tolerance = 1e-6;
cfg.equivalence_min_correlation = 1 - 1e-10;

% Resolution diagnostics are matrix-free. These seeds are selected by
% farthest-point sampling on the canonical mesh and are diagnostic only.
cfg.resolution_n_diagnostic_seeds = 64;
cfg.resolution_mass_fraction = 0.80;
cfg.resolution_max_records = Inf;

% Explicit duplicate resolution. Never silently choose between two valid
% inverse files for the same participant and condition.
cfg.inventory_duplicate_overrides = table( ...
    "sub-88006161", "MDD", "restEO", ...
    "redfMfsub-88006161_MDD_restEO_scale1_as_uV.mat", ...
    "Prefer canonical rereferenced file with rejected epochs removed", ...
    'VariableNames', {'subject_id','group','condition','preferred_basename','rationale'});

cfg.random_seed = 31072026;

% Frozen participant split and anatomical scaffold.
cfg.metadata_xlsx = 'C:\MATLAB\2026 TDBRAIN dataset\dataset\TDBRAIN_participants_V3.xlsx';
cfg.discovery_fraction = 0.70;
cfg.age_band_edges = [18 30 45 60 Inf];
cfg.atlas_xml = fullfile(cfg.spm_dir, 'tpm', 'labels_Neuromorphometrics.xml');
cfg.atlas_cortical_min_index = 100;
cfg.atlas_projection_max_mm = 8;
cfg.atlas_min_component_vertices = 10;
cfg.support_rank_fraction = 0.80;
cfg.support_min_count_per_hemisphere = 6;
cfg.reliability_min_epochs_per_half = 5;
cfg.candidate_prevalence_percentile = 0.75;
cfg.candidate_score_weights = struct('reliability',0.35, ...
    'prevalence',0.25,'precision',0.20,'separability',0.20);
cfg.confirmatory_candidate_count = 8;
cfg.candidate_min_support_vertices = 50;
cfg.candidate_max_bands_per_support = 1;
cfg.candidate_component_scaling = 'empirical_percentile_within_eligible_discovery_family';
cfg.physiology_bootstrap_samples = 2000;
cfg.physiology_discovery_shortlist = 12;
cfg.physiology_score_weights = struct('effect_size',0.35, ...
    'sign_consistency',0.20,'bootstrap_stability',0.20, ...
    'reliability',0.15,'separability',0.10);
cfg.dcm_max_nodes = 6;
cfg.dcm_min_nodes = 4;
cfg.dcm_max_profile_cosine = 0.95;
cfg.dcm_min_coordinate_distance_mm = 30;
end
