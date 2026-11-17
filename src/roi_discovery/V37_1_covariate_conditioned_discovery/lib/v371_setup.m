function cfg = v371_setup()
%V371_SETUP Initialize SPM and all inherited V37 helpers.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'00_config'));
cfg = v371_config();
restoredefaultpath;
addpath(cfg.spm_dir);
addpath(genpath(fullfile(cfg.spm_dir,'config')));
addpath(genpath(fullfile(cfg.spm_dir,'matlabbatch')));
addpath(genpath(fullfile(cfg.spm_dir,'external','fieldtrip')));
addpath(genpath(cfg.v32_root)); addpath(genpath(cfg.v33_root));
addpath(genpath(cfg.v34_root)); addpath(genpath(cfg.v35_root));
addpath(genpath(cfg.v36_root)); addpath(genpath(cfg.v37_root));
addpath(genpath(root));
spm('defaults','eeg'); spm_jobman('initcfg');
if exist('ft_defaults','file')==2, ft_defaults; end
rng(cfg.random_seed,'twister');
end
