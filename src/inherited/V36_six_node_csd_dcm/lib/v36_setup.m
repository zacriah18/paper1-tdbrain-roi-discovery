function cfg=v36_setup()
root=fileparts(fileparts(mfilename('fullpath')));
v32='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V32_induced';
v33='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V33_broadband_mesh';
v34='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V34_DCM_aligned_patches';
v35='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V35_patch_network_audit';
addpath(fullfile(root,'00_config'),fullfile(root,'lib'), ...
    fullfile(v32,'00_config'),fullfile(v32,'lib'),fullfile(v33,'00_config'),fullfile(v33,'lib'), ...
    fullfile(v34,'00_config'),fullfile(v34,'lib'),fullfile(v35,'00_config'),fullfile(v35,'lib'));
cfg=v36_config();addpath(cfg.spm_dir);spm('defaults','EEG');spm_jobman('initcfg');
end
