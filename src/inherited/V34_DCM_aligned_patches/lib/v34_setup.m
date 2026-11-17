function cfg=v34_setup()
root=fileparts(fileparts(mfilename('fullpath')));
v32='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V32_induced';
v33='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V33_broadband_mesh';
addpath(fullfile(root,'00_config'),fullfile(root,'lib'),fullfile(v32,'00_config'), ...
    fullfile(v32,'lib'),fullfile(v33,'00_config'),fullfile(v33,'lib'));
cfg=v34_config();addpath(cfg.spm_dir);spm('defaults','EEG');spm_jobman('initcfg');
end
