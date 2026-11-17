function cfg = v37_setup()
%V37_SETUP Initialize SPM and the V37 pipeline.
this_file = mfilename('fullpath');
pipeline_root = fileparts(fileparts(this_file));
addpath(fullfile(pipeline_root, '00_config'));
cfg = v37_config();

restoredefaultpath;
addpath(cfg.spm_dir);
addpath(genpath(fullfile(cfg.spm_dir, 'config')));
addpath(genpath(fullfile(cfg.spm_dir, 'matlabbatch')));
addpath(genpath(fullfile(cfg.spm_dir, 'external', 'fieldtrip')));
addpath(genpath(cfg.v32_root));
addpath(genpath(cfg.v33_root));
addpath(genpath(cfg.v34_root));
addpath(genpath(cfg.v35_root));
addpath(genpath(cfg.v36_root));
addpath(genpath(pipeline_root));
spm('defaults', 'eeg');
spm_jobman('initcfg');
if exist('ft_defaults', 'file') == 2, ft_defaults; end
rng(cfg.random_seed, 'twister');
end
