function cfg=v33_config()
% Frozen configuration for the broadband full-temporal-subspace analysis.
v32_root='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V32_induced';
addpath(fullfile(v32_root,'00_config'));
cfg=v32_config();
cfg.pipeline_version='V33_broadband_mesh_0.1.0';
cfg.v32_root=v32_root;
cfg.output_root=fullfile(cfg.project_root,'derivatives','V33_broadband_mesh');
cfg.temporal_orthogonality_tolerance=1e-6;
cfg.broadband_equivalence_abs_tolerance=1e-8;
cfg.broadband_equivalence_rel_tolerance=1e-6;
cfg.group_shortlist_max_supports=6;
cfg.dcm_local_patch_radius_mm=16;
cfg.dcm_local_patch_target_coverage=0.80;
cfg.dcm_local_patch_max_centres=20;
cfg.dcm_single_patch_min_support_coverage=0.50;
end
