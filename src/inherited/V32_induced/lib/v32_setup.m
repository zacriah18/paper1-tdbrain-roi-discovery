function cfg = v32_setup()
%V32_SETUP Add SPM and V32 folders, initialize SPM, and return config.

this_file = mfilename('fullpath');
pipeline_root = fileparts(fileparts(this_file));
addpath(fullfile(pipeline_root, '00_config'));
cfg = v32_config();

restoredefaultpath;
addpath(cfg.spm_dir);
addpath(genpath(fullfile(cfg.spm_dir, 'config')));
addpath(genpath(fullfile(cfg.spm_dir, 'matlabbatch')));
addpath(genpath(fullfile(cfg.spm_dir, 'external', 'fieldtrip')));
addpath(genpath(pipeline_root));

spm('defaults', 'eeg');
spm_jobman('initcfg');
if exist('ft_defaults', 'file') == 2
    ft_defaults;
end

rng(cfg.random_seed, 'twister');
end
