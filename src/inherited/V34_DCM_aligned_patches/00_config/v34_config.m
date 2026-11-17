function cfg=v34_config()
v33_root='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V33_broadband_mesh';
addpath(fullfile(v33_root,'00_config'));cfg=v33_config();
cfg.pipeline_version='V34_DCM_aligned_patches_0.1.0';cfg.v33_root=v33_root;
cfg.output_root=fullfile(cfg.project_root,'derivatives','V34_DCM_aligned_patches');
cfg.patch_radius_mm=16;cfg.patch_core_percentile=0.75;
cfg.patch_min_core_criteria=3;cfg.patch_min_reliability=0.80;
cfg.patch_candidate_max=12;cfg.patch_candidate_min_distance_mm=30;
cfg.separation_folds=5;
end
