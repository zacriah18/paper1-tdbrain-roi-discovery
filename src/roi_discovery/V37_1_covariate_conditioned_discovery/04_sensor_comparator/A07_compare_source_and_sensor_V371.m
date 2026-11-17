%% Compare completed source and sensor models without refitting either model.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'04_sensor_comparator');
O=load(fullfile(cfg.output_root,'02_conditioned_models','A02_conditioned_nested_models.mat'),'result');source=O.result;
S=load(fullfile(out,'A06_sensor_comparator.mat'),'result');sensor=S.result;
model=["demographic";"QC_only";"source_neural_only";"source_combined";"sensor_only";"sensor_combined"];
m={source.metrics.demographic;source.metrics.qc_only;source.metrics.neural_only;source.metrics.combined; ...
    sensor.metrics.sensor_only;sensor.metrics.sensor_combined};
AUC=cellfun(@(x)x.AUC,m);log_loss=cellfun(@(x)x.log_loss,m);Brier=cellfun(@(x)x.Brier,m);
balanced_accuracy=cellfun(@(x)x.balanced_accuracy,m);sensitivity=cellfun(@(x)x.sensitivity,m);
specificity=cellfun(@(x)x.specificity,m);
comparison=table(model,AUC,log_loss,Brier,balanced_accuracy,sensitivity,specificity);
writetable(comparison,fullfile(out,'A07_source_sensor_model_comparison.csv'));
fprintf('Source combined AUC %.3f; sensor combined AUC %.3f; validation read=0.\n', ...
    source.metrics.combined.AUC,sensor.metrics.sensor_combined.AUC);
