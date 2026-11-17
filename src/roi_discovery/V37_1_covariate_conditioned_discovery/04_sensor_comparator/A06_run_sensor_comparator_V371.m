%% Run sensor comparator with the exact locked V37.1 folds.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'04_sensor_comparator');
S=load(fullfile(out,'A05_sensor_participant_features.mat'),'sensor');sensor=S.sensor;
F=load(fullfile(cfg.output_root,'01_folds','A01_locked_nested_folds.mat'),'folds');folds=F.folds;
if ~isequal(string(sensor.participants.subject_id),folds.subject_id),error('V371:FoldJoin','Sensor order differs from locked folds.');end
y=double(string(sensor.participants.group)=="MDD");result=v371_run_sensor_nested(sensor,cfg,y,folds);
prediction=sensor.participants(:,{'subject_id','group','age','sex','age_band','condition_availability'});
prediction.sensor_only_probability=result.probability(:,1);prediction.sensor_combined_probability=result.probability(:,2);
writetable(prediction,fullfile(out,'A06_sensor_out_of_fold_predictions.csv'));
writetable(result.fold_results,fullfile(out,'A06_sensor_outer_fold_results.csv'));
writetable(table(result.channel_label,result.eligible_count,result.combined_selection_count, ...
    result.combined_selection_frequency,'VariableNames',{'channel_label','eligible_outer_folds', ...
    'selected_outer_folds','selection_frequency'}),fullfile(out,'A06_sensor_channel_stability.csv'));
model=["sensor_only";"sensor_combined"];
m={result.metrics.sensor_only;result.metrics.sensor_combined};
AUC=cellfun(@(x)x.AUC,m);log_loss=cellfun(@(x)x.log_loss,m);Brier=cellfun(@(x)x.Brier,m);
balanced_accuracy=cellfun(@(x)x.balanced_accuracy,m);
sensor_performance=table(model,AUC,log_loss,Brier,balanced_accuracy);
writetable(sensor_performance,fullfile(out,'A06_sensor_model_performance.csv'));
save(fullfile(out,'A06_sensor_comparator.mat'),'result','sensor','folds','sensor_performance','cfg','-v7.3');
fprintf('Sensor combined AUC %.3f; validation read=0. Source comparison is a separate post-completion step.\n', ...
    result.metrics.sensor_combined.AUC);
