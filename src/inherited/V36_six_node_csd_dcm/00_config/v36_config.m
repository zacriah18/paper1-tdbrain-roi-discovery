function cfg=v36_config()
v35_root='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V35_patch_network_audit';
addpath(fullfile(v35_root,'00_config'));cfg=v35_config();
cfg.pipeline_version='V36_six_node_csd_dcm_0.1.0';cfg.v35_root=v35_root;
cfg.output_root=fullfile(cfg.project_root,'derivatives','V36_six_node_csd_dcm');
cfg.seed_node_manifest=fullfile(cfg.project_root,'derivatives','V35_patch_network_audit', ...
    '04_dcm_handoff','A04_provisional_identifiable_DCM_nodes.csv');
cfg.node_manifest=fullfile(cfg.output_root,'01_preflight','A01b_exact_SPM_IMG_six_node_handoff.csv');
if ~exist(cfg.node_manifest,'file'),cfg.node_manifest=cfg.seed_node_manifest;end
cfg.focal_v34_rank=2;cfg.exact_subspace_warning=0.80;
cfg.dcm_analysis='CSD';cfg.neuronal_model='CMC';cfg.spatial_model='IMG';
cfg.patch_radius_mm=16;cfg.regional_spatial_modes=6;cfg.channel_modes=8;
cfg.time_window_ms=[0 3992];cfg.frequency_window_hz=[4 45];
cfg.time_decimation=1;cfg.detrend_terms=1;cfg.hanning=false;
cfg.max_iterations=128;cfg.parent_hypothesis='H5_PARENT_FOCAL_HUB';
cfg.resume=true;cfg.retry_errors=false;cfg.max_recordings=Inf;cfg.start_row=1;cfg.end_row=Inf;
v=str2double(getenv('TDBRAIN_V36_MAX_RECORDINGS'));if isfinite(v)&&v>0,cfg.max_recordings=v;end
v=str2double(getenv('TDBRAIN_V36_START_ROW'));if isfinite(v)&&v>0,cfg.start_row=round(v);end
v=str2double(getenv('TDBRAIN_V36_END_ROW'));if isfinite(v)&&v>0,cfg.end_row=round(v);end
v=lower(string(getenv('TDBRAIN_V36_RETRY_ERRORS')));if ismember(v,["1","true","yes"]),cfg.retry_errors=true;end
end
