%% V37.1 observed discovery analysis. The 98 validation participants are inaccessible.
clear; clc;
root = fileparts(mfilename('fullpath'));
fold_file = fullfile(fileparts(root),'derivatives', ...
    'V37_1_covariate_conditioned_discovery','01_folds','A01_locked_nested_folds.mat');
if ~exist(fold_file,'file')
    run(fullfile(root,'01_folds','A01_freeze_nested_folds_V371.m'));
end
run(fullfile(root,'02_conditioned_models','A02_run_conditioned_nested_models_V371.m'));
fprintf('V37.1 OBSERVED ANALYSIS COMPLETE. Validation participants read: 0.\n');
