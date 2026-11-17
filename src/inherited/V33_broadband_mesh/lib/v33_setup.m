function cfg=v33_setup()
root=fileparts(fileparts(mfilename('fullpath')));
v32_root='C:\MATLAB\2026 TDBRAIN V31 source ROI discovery\V32_induced';
addpath(fullfile(root,'00_config'),fullfile(root,'lib'), ...
    fullfile(v32_root,'00_config'),fullfile(v32_root,'lib'));
cfg=v33_config();
addpath(cfg.spm_dir);
spm('defaults','EEG');
spm_jobman('initcfg');
end
