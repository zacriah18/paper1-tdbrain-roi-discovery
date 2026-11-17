%% Run repeated nested supervised ROI discovery with neural features only.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'lib'));
cfg = v37_setup();
out = fullfile(cfg.output_root, '04_supervised_discovery');
if ~exist(out, 'dir'), mkdir(out); end
D = load(fullfile(cfg.output_root, '03_participant_features', ...
    'A03_participant_spectral_landscapes.mat'), 'dataset');
dataset = D.dataset;
y = double(dataset.participants.group == "MDD");
result = v37_run_nested_cv(dataset,cfg,y);

prediction = dataset.participants(:,{'subject_id','group','age','sex','age_band'});
prediction.observed_MDD = logical(y);
prediction.neural_probability = result.oof_neural_probability;
prediction.demographic_probability = result.oof_demographic_probability;
prediction.n_outer_predictions = result.oof_prediction_count;
writetable(prediction,fullfile(out,'A04_out_of_fold_predictions.csv'));
writetable(result.fold_results,fullfile(out,'A04_outer_fold_results.csv'));

patch_summary = table(result.patch_id,result.eligibility_count, ...
    result.selection_count,result.selection_frequency_when_eligible, ...
    result.mean_coefficient_magnitude_when_eligible, ...
    'VariableNames',{'patch_id','eligible_outer_folds','selected_outer_folds', ...
    'selection_frequency_when_eligible','mean_coefficient_magnitude_when_eligible'});
writetable(patch_summary,fullfile(out,'A04_patch_selection_stability.csv'));
summary = table(height(dataset.participants),result.neural_AUC, ...
    result.demographic_AUC,result.neural_log_loss,result.demographic_log_loss,false,0, ...
    'VariableNames',{'n_discovery_participants','neural_only_AUC', ...
    'age_sex_only_AUC','neural_only_log_loss','age_sex_only_log_loss', ...
    'age_sex_used_for_neural_selection','validation_participants_read'});
writetable(summary,fullfile(out,'A04_discovery_performance_summary.csv'));
save(fullfile(out,'A04_nested_supervised_discovery.mat'),'result','dataset','cfg','-v7.3');
fprintf('Neural-only OOF AUC %.3f; age/sex benchmark AUC %.3f.\n', ...
    result.neural_AUC,result.demographic_AUC);
