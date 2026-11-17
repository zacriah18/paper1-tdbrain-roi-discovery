%% Aggregate and audit all continuous-age parametric-null shards.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'lib'));
cfg = v371_setup();
out = fullfile(cfg.output_root,'08_robustness_sensitivities', ...
    'continuous_age_parametric_null');
L = load(fullfile(out,'A19a_continuous_age_null_freeze.mat'),'freeze');
freeze = L.freeze; count = freeze.bootstrap_count;
shard_dir = fullfile(out,'shards');

index = (1:count)'; seed = nan(count,1); attempts = nan(count,1);
generated_MDD = nan(count,1); deltaLL = nan(count,1); deltaAUC = nan(count,1);
elapsed_seconds = nan(count,1); labels = false(count,numel(freeze.y_observed));
for b = 1:count
    file = fullfile(shard_dir,sprintf('bootstrap_%04d.mat',b));
    if ~exist(file,'file'), error('V371:MissingShard','Missing %s',file); end
    S = load(file,'entry'); e = S.entry;
    if e.bootstrap_index ~= b, error('V371:ShardIndex','Index mismatch in %s',file); end
    seed(b)=e.seed; attempts(b)=e.attempts; generated_MDD(b)=e.generated_MDD;
    deltaLL(b)=e.incremental_log_loss; deltaAUC(b)=e.incremental_AUC;
    elapsed_seconds(b)=e.elapsed_seconds; labels(b,:)=logical(e.generated_label(:))';
end
if any(~isfinite(deltaLL)) || any(~isfinite(deltaAUC))
    error('V371:NullFinite','Non-finite bootstrap statistic.');
end

observed = readtable(fullfile(cfg.output_root,'02_conditioned_models', ...
    'A02_primary_incremental_performance.csv'));
observedLL = observed.incremental_log_loss_combined_vs_demographic(1);
observedAUC = observed.incremental_AUC_combined_vs_demographic(1);
exceedLL = sum(deltaLL >= observedLL); exceedAUC = sum(deltaAUC >= observedAUC);
pLL = (1 + exceedLL)/(1 + count); pAUC = (1 + exceedAUC)/(1 + count);

values = table(index,seed,attempts,generated_MDD,deltaLL,deltaAUC,elapsed_seconds);
writetable(values,fullfile(out,'A19c_continuous_age_null_values.csv'));
summary = table(observedLL,count,exceedLL,pLL,observedAUC,exceedAUC,pAUC, ...
    mean(deltaLL),std(deltaLL),median(deltaLL),prctile(deltaLL,2.5), ...
    prctile(deltaLL,97.5),mean(deltaAUC),std(deltaAUC),median(deltaAUC), ...
    prctile(deltaAUC,2.5),prctile(deltaAUC,97.5),0, ...
    'VariableNames',{'observed_incremental_log_loss','completed_bootstraps', ...
    'null_exceedances_log_loss','primary_empirical_p_value', ...
    'observed_incremental_AUC','null_exceedances_AUC','secondary_empirical_p_value', ...
    'null_mean_log_loss','null_sd_log_loss','null_median_log_loss', ...
    'null_q025_log_loss','null_q975_log_loss','null_mean_AUC','null_sd_AUC', ...
    'null_median_AUC','null_q025_AUC','null_q975_AUC','validation_participants_read'});
writetable(summary,fullfile(out,'A19c_continuous_age_null_summary.csv'));

expected_seed = freeze.bootstrap_seed + 10000*index;
audit = table(count,numel(freeze.y_observed),size(unique(labels,'rows'),1), ...
    sum(seed==expected_seed),max(attempts),min(generated_MDD),median(generated_MDD), ...
    max(generated_MDD),0, ...
    'VariableNames',{'bootstraps','participants','unique_label_vectors', ...
    'seed_matches','maximum_generation_attempts','minimum_generated_MDD', ...
    'median_generated_MDD','maximum_generated_MDD','validation_participants_read'});
writetable(audit,fullfile(out,'A19c_continuous_age_null_design_audit.csv'));
save(fullfile(out,'A19c_continuous_age_null_aggregate.mat'), ...
    'values','summary','audit','labels','freeze','-v7.3');
fprintf('Continuous-age null complete: pLL=%.6f (%d exceed), pAUC=%.6f (%d exceed).\n', ...
    pLL,exceedLL,pAUC,exceedAUC);
