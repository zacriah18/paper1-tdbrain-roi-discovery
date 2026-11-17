function cfg=v35_config()
v34_root='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V34_DCM_aligned_patches';
addpath(fullfile(v34_root,'00_config'));cfg=v34_config();
cfg.pipeline_version='V35_patch_network_audit_0.1.0';
cfg.v34_root=v34_root;
cfg.output_root=fullfile(cfg.project_root,'derivatives','V35_patch_network_audit');
cfg.node_spatial_modes=6;
cfg.connectivity_frequency_hz=[1 45];
cfg.connectivity_target_fsample=100;
cfg.granger_order_samples=4; % 40 ms at the frozen 100 Hz analysis rate.
cfg.identifiability_profile_warning=0.90;
cfg.identifiability_subspace_warning=0.80;
cfg.whitening_eigenvalue_floor=1e-6;
cfg.max_recordings=Inf;
override=str2double(getenv('TDBRAIN_V35_MAX_RECORDINGS'));
if isfinite(override)&&override>0,cfg.max_recordings=override;end
end
