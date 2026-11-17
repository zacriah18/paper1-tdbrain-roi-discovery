%% Participant-label permutations through the complete nested pipeline.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'lib'));
cfg = v37_setup();
out = fullfile(cfg.output_root, '04_supervised_discovery');
if ~exist(out, 'dir'), mkdir(out); end
D = load(fullfile(cfg.output_root, '03_participant_features', ...
    'A03_participant_spectral_landscapes.mat'), 'dataset');
O = load(fullfile(out,'A04_nested_supervised_discovery.mat'),'result');
dataset = D.dataset; observed = O.result.neural_AUC;
file = fullfile(out,'A04b_full_pipeline_permutations.mat');
if exist(file,'file')
    R = load(file,'permutation_AUC'); permutation_AUC = R.permutation_AUC;
else
    permutation_AUC = nan(cfg.permutation_count,1);
end
if numel(permutation_AUC) ~= cfg.permutation_count
    permutation_AUC(cfg.permutation_count,1) = NaN;
end
y = double(dataset.participants.group == "MDD");
rng(cfg.random_seed+900000,'twister');
orders = zeros(numel(y),cfg.permutation_count,'uint16');
for p = 1:cfg.permutation_count, orders(:,p)=uint16(randperm(numel(y))); end
for p = 1:cfg.permutation_count
    if isfinite(permutation_AUC(p)), continue; end
    yp = y(double(orders(:,p)));
    r = v37_run_nested_cv(dataset,cfg,yp);
    permutation_AUC(p) = r.neural_AUC;
    save(file,'permutation_AUC','observed','cfg','-v7.3');
    fprintf('permutation %d/%d: AUC %.3f\n',p,cfg.permutation_count,permutation_AUC(p));
end
p_value = (1+sum(permutation_AUC>=observed))/(1+sum(isfinite(permutation_AUC)));
summary = table(observed,mean(permutation_AUC,'omitnan'), ...
    std(permutation_AUC,'omitnan'),p_value,sum(isfinite(permutation_AUC)), ...
    'VariableNames',{'observed_neural_AUC','permutation_mean_AUC', ...
    'permutation_sd_AUC','empirical_p_value','completed_permutations'});
writetable(summary,fullfile(out,'A04b_permutation_summary.csv'));
