%% Freeze the continuous-nuisance parametric null generator.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'lib'));
cfg = v371_setup();

feature_file = fullfile(cfg.project_root,'derivatives', ...
    'V37_DCM_concordant_ROI_discovery','03_participant_features', ...
    'A03_participant_spectral_landscapes.mat');
fold_file = fullfile(cfg.output_root,'01_folds','A01_locked_nested_folds.mat');
D = load(feature_file,'dataset'); dataset = D.dataset;
F = load(fold_file,'folds'); folds = F.folds;
P = dataset.participants;

if height(P) ~= 225 || any(string(P.assignment) ~= "discovery")
    error('V371:ValidationBoundary','Null generator must use discovery only.');
end
if ~isequal(string(P.subject_id),string(folds.subject_id))
    error('V371:FoldJoin','Dataset and fold orders differ.');
end

y = double(string(P.group) == "MDD");
[Z,nuisance_names] = v371_nuisance_matrix(P);
all_rows = true(height(P),1);
[Zs,~,preparation] = v37_prepare_matrix(Z,all_rows,all_rows);
generator_model = v37_ridge_logistic(Zs,y,cfg.demographic_ridge);
null_probability = local_sigmoid([ones(height(P),1),Zs] * generator_model.beta);

null_definition = ['Parametric demographic-null bootstrap: independent Bernoulli labels ' ...
    'generated from age, centred age squared, sex and paired-condition availability; ' ...
    'the complete nested demographic-versus-neural search is refit for every draw.'];
bootstrap_count = 1000;
bootstrap_seed = 90820261;

out = fullfile(cfg.output_root,'08_robustness_sensitivities', ...
    'continuous_age_parametric_null');
if ~exist(out,'dir'), mkdir(out); end

manifest = P(:,{'subject_id','group','age','sex','age_band','condition_availability'});
manifest.observed_label = y;
manifest.null_probability_MDD = null_probability;
writetable(manifest,fullfile(out,'A19a_null_probability_manifest.csv'));

term = ["intercept"; string(nuisance_names(:))];
coefficient = generator_model.beta;
coefficient_table = table(term,coefficient);
writetable(coefficient_table,fullfile(out,'A19a_null_generator_coefficients.csv'));

freeze = struct('null_definition',null_definition,'bootstrap_count',bootstrap_count, ...
    'bootstrap_seed',bootstrap_seed,'y_observed',y,'null_probability',null_probability, ...
    'generator_model',generator_model,'preparation',preparation, ...
    'nuisance_names',{nuisance_names},'subject_id',string(P.subject_id), ...
    'validation_participants_read',0);
save(fullfile(out,'A19a_continuous_age_null_freeze.mat'), ...
    'freeze','dataset','folds','cfg','-v7.3');

summary = table(string(null_definition),height(P),sum(y),min(null_probability), ...
    median(null_probability),max(null_probability),mean(null_probability), ...
    bootstrap_count,bootstrap_seed,0, ...
    'VariableNames',{'null_definition','participants','observed_MDD', ...
    'minimum_null_probability','median_null_probability','maximum_null_probability', ...
    'mean_null_probability','bootstrap_count','bootstrap_seed', ...
    'validation_participants_read'});
writetable(summary,fullfile(out,'A19a_null_design_summary.csv'));
fprintf('Frozen continuous-age parametric null for %d discovery participants; validation read=0.\n',height(P));

function p = local_sigmoid(x)
p = 1 ./ (1 + exp(-max(min(x,35),-35)));
end
