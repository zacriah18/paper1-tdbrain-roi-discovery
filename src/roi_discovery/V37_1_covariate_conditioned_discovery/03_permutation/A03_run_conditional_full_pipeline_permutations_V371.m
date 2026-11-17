%% Conditional full-pipeline permutation test on the 225-person discovery set.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'lib'));
cfg = v371_setup(); out = fullfile(cfg.output_root,'03_permutation');
if ~exist(out,'dir'), mkdir(out); end

D = load(fullfile(cfg.project_root,'derivatives','V37_DCM_concordant_ROI_discovery', ...
    '03_participant_features','A03_participant_spectral_landscapes.mat'),'dataset');
dataset = D.dataset; P = dataset.participants;
if height(P)~=cfg.expected_discovery_participants || any(string(P.assignment)~="discovery")
    error('V371:ValidationBoundary','Permutation stage permits only 225 discovery participants.');
end
F = load(fullfile(cfg.output_root,'01_folds','A01_locked_nested_folds.mat'),'folds');
folds = F.folds;
O = load(fullfile(cfg.output_root,'02_conditioned_models', ...
    'A02_conditioned_nested_models.mat'),'result');
observed = struct('incremental_log_loss',O.result.primary_incremental_log_loss, ...
    'incremental_AUC',O.result.secondary_incremental_AUC, ...
    'combined_log_loss',O.result.metrics.combined.log_loss, ...
    'combined_AUC',O.result.metrics.combined.AUC);

nperm = cfg.permutation_count;
checkpoint = fullfile(out,'A03_conditional_full_pipeline_permutations.mat');
if exist(checkpoint,'file')
    R = load(checkpoint,'null_incremental_log_loss','null_incremental_AUC', ...
        'null_combined_log_loss','null_combined_AUC','permutation_seed','permutation_attempts');
    null_incremental_log_loss = local_resize(R.null_incremental_log_loss,nperm);
    null_incremental_AUC = local_resize(R.null_incremental_AUC,nperm);
    null_combined_log_loss = local_resize(R.null_combined_log_loss,nperm);
    null_combined_AUC = local_resize(R.null_combined_AUC,nperm);
    permutation_seed = local_resize(R.permutation_seed,nperm);
    permutation_attempts = local_resize(R.permutation_attempts,nperm);
else
    null_incremental_log_loss = nan(nperm,1); null_incremental_AUC = nan(nperm,1);
    null_combined_log_loss = nan(nperm,1); null_combined_AUC = nan(nperm,1);
    permutation_seed = nan(nperm,1); permutation_attempts = nan(nperm,1);
end

y = double(string(P.group)=="MDD");
for p = 1:nperm
    if isfinite(null_incremental_log_loss(p)), continue; end
    seed = cfg.permutation_seed + 10000*p;
    [yp,meta] = v371_conditional_permutation(y,P,seed,folds.outer_fold);
    rp = v371_run_conditioned_nested(dataset,cfg,yp,folds,false);
    null_incremental_log_loss(p) = rp.primary_incremental_log_loss;
    null_incremental_AUC(p) = rp.secondary_incremental_AUC;
    null_combined_log_loss(p) = rp.metrics.combined.log_loss;
    null_combined_AUC(p) = rp.metrics.combined.AUC;
    permutation_seed(p) = seed; permutation_attempts(p) = meta.attempts;
    save(checkpoint,'null_incremental_log_loss','null_incremental_AUC', ...
        'null_combined_log_loss','null_combined_AUC','permutation_seed', ...
        'permutation_attempts','observed','cfg','-v7.3');
    fprintf('conditional permutation %d/%d: deltaLL=%.4f deltaAUC=%.4f\n', ...
        p,nperm,null_incremental_log_loss(p),null_incremental_AUC(p));
end

completed = sum(isfinite(null_incremental_log_loss));
p_primary = (1+sum(null_incremental_log_loss>=observed.incremental_log_loss,'omitnan'))/(1+completed);
p_secondary = (1+sum(null_incremental_AUC>=observed.incremental_AUC,'omitnan'))/(1+completed);
summary = table(observed.incremental_log_loss,mean(null_incremental_log_loss,'omitnan'), ...
    std(null_incremental_log_loss,'omitnan'),p_primary,observed.incremental_AUC, ...
    mean(null_incremental_AUC,'omitnan'),std(null_incremental_AUC,'omitnan'), ...
    p_secondary,completed,0, ...
    'VariableNames',{'observed_incremental_log_loss','null_mean_incremental_log_loss', ...
    'null_sd_incremental_log_loss','primary_empirical_p_value', ...
    'observed_incremental_AUC','null_mean_incremental_AUC', ...
    'null_sd_incremental_AUC','secondary_empirical_p_value', ...
    'completed_valid_permutations','validation_participants_read'});
writetable(summary,fullfile(out,'A03_conditional_permutation_summary.csv'));

[~,~,sex_binary] = v371_nuisance_matrix(P);
key = string(P.age_band)+"|sex="+string(sex_binary)+"|condition="+string(P.condition_availability);
[block,~,bid] = unique(key,'stable'); block_n = accumarray(bid,1);
block_MDD = accumarray(bid,y); block_HC = block_n-block_MDD;
writetable(table(block,block_n,block_HC,block_MDD), ...
    fullfile(out,'A03_conditional_permutation_blocks.csv'));
fprintf('Permutation test complete: n=%d primary p=%.6f; validation read=0.\n',completed,p_primary);

function x = local_resize(x,n)
x = x(:); x(end+1:n,1) = NaN; x = x(1:n);
end
