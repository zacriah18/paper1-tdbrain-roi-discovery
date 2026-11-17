%% V37.1 discovery robustness sensitivity without validation access.
% Runs one prespecified participant subset through the same conditioned
% nested sparse-group model. The frozen primary outputs are never changed.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'lib'));
cfg = v371_setup();

sensitivity = lower(strtrim(getenv('TDBRAIN_V371_SENSITIVITY')));
if isempty(sensitivity), sensitivity = 'high_qc'; end
valid = {'high_qc','exclude_repeated_sessions'};
if ~ismember(sensitivity,valid)
    error('V371:SensitivityName','Unknown sensitivity: %s',sensitivity);
end

feature_file = fullfile(cfg.project_root,'derivatives', ...
    'V37_DCM_concordant_ROI_discovery','03_participant_features', ...
    'A03_participant_spectral_landscapes.mat');
fold_file = fullfile(cfg.output_root,'01_folds','A01_locked_nested_folds.mat');
D = load(feature_file,'dataset'); dataset_full = D.dataset;
F = load(fold_file,'folds'); primary_folds = F.folds;
P = dataset_full.participants;

if height(P) ~= 225 || any(string(P.assignment) ~= "discovery")
    error('V371:ValidationBoundary','Sensitivity input must be the 225-person discovery set.');
end
if ~isequal(string(P.subject_id),string(primary_folds.subject_id))
    error('V371:FoldJoin','Feature and primary-fold participant orders differ.');
end

good_epochs = double(dataset_full.technical.good_epoch_count);
repeated_ids = string({'sub-88006161','sub-88009901','sub-88010981', ...
    'sub-88012461','sub-88017409','sub-88022089','sub-88023125','sub-88045713'});

switch sensitivity
    case 'high_qc'
        % Frozen definition: both EC and EO available, with >=20 retained
        % epochs in each condition. No diagnosis or source feature is used.
        include = dataset_full.has_paired_conditions(:) & ...
            all(isfinite(good_epochs),2) & all(good_epochs >= 20,2);
        definition = 'paired EC/EO and at least 20 retained epochs in each condition';
    case 'exclude_repeated_sessions'
        % Remove every discovery participant whose Stage-B shortlist had
        % more than one eligible session, irrespective of final path choice.
        include = ~ismember(string(P.subject_id),repeated_ids);
        definition = 'exclude all participants with multiple Stage-B eligible sessions';
end

dataset = local_subset_dataset(dataset_full,include);
cfg.expected_discovery_participants = height(dataset.participants);
cfg.pipeline_version = cfg.pipeline_version + "_sensitivity_" + sensitivity;
folds = local_restrict_outer_rebuild_inner(primary_folds,dataset.participants,include,cfg);
y = double(string(dataset.participants.group) == "MDD");

out = fullfile(cfg.output_root,'08_robustness_sensitivities',sensitivity);
if ~exist(out,'dir'), mkdir(out); end

manifest = P(:,{'subject_id','group','age','sex','age_band','condition_availability'});
manifest.good_epochs_EC = good_epochs(:,1);
manifest.good_epochs_EO = good_epochs(:,2);
manifest.repeated_session_participant = ismember(string(P.subject_id),repeated_ids);
manifest.included = include;
manifest.exclusion_reason = repmat("",height(P),1);
manifest.exclusion_reason(~include) = "not eligible for " + sensitivity;
writetable(manifest,fullfile(out,'A18_participant_inclusion_manifest.csv'));

fold_manifest = dataset.participants(:,{'subject_id','group','age','sex','age_band','condition_availability'});
for r = 1:cfg.outer_repeats
    fold_manifest.(sprintf('repeat_%d_outer_fold',r)) = folds.outer_fold(:,r);
end
writetable(fold_manifest,fullfile(out,'A18_sensitivity_outer_folds.csv'));

fprintf('Running %s: n=%d, HC=%d, MDD=%d. Definition: %s\n', ...
    sensitivity,height(dataset.participants),sum(y==0),sum(y==1),definition);
result = v371_run_conditioned_nested(dataset,cfg,y,folds,false);

prediction = dataset.participants(:,{'subject_id','group','age','sex','age_band','condition_availability'});
prediction.demographic_probability = result.probability(:,2);
prediction.combined_probability = result.probability(:,5);
writetable(prediction,fullfile(out,'A18_out_of_fold_predictions.csv'));
writetable(result.fold_results,fullfile(out,'A18_outer_fold_comparison.csv'));

names = ["demographic","combined"];
rows = table();
for i = 1:numel(names)
    name = names(i); m = result.metrics.(name);
    row = table(name,m.AUC,m.log_loss,m.Brier,m.balanced_accuracy,m.sensitivity, ...
        m.specificity,m.calibration_intercept,m.calibration_slope, ...
        'VariableNames',{'model','AUC','log_loss','Brier','balanced_accuracy', ...
        'sensitivity','specificity','calibration_intercept','calibration_slope'});
    rows = [rows; row]; %#ok<AGROW>
end
writetable(rows,fullfile(out,'A18_model_performance.csv'));

summary = table(string(sensitivity),string(definition),height(dataset.participants), ...
    sum(y==0),sum(y==1),result.primary_incremental_log_loss, ...
    result.secondary_incremental_AUC,0, ...
    'VariableNames',{'sensitivity','definition','participants','HC','MDD', ...
    'incremental_log_loss_combined_vs_demographic', ...
    'incremental_AUC_combined_vs_demographic','validation_participants_read'});
writetable(summary,fullfile(out,'A18_sensitivity_summary.csv'));

patch = table(result.patch_id,result.eligible_count,result.combined_selection_count, ...
    result.combined_selection_frequency,result.combined_mean_coefficient_magnitude, ...
    'VariableNames',{'patch_id','eligible_outer_folds','combined_selected_outer_folds', ...
    'combined_selection_frequency','combined_mean_coefficient_magnitude'});
writetable(patch,fullfile(out,'A18_patch_stability.csv'));
save(fullfile(out,'A18_discovery_sensitivity.mat'), ...
    'result','dataset','folds','cfg','include','definition','-v7.3');

fprintf('COMPLETE %s: deltaLL=%.6f deltaAUC=%.6f validation read=0.\n', ...
    sensitivity,result.primary_incremental_log_loss,result.secondary_incremental_AUC);

function dataset = local_subset_dataset(source,include)
include = logical(include(:)); n = height(source.participants);
if numel(include) ~= n, error('V371:SubsetSize','Participant mask has the wrong size.'); end
dataset = source;
dataset.participants = source.participants(include,:);
dataset.average_relative_log_spectrum = source.average_relative_log_spectrum(include,:,:);
dataset.signed_EC_minus_EO_log_spectrum = source.signed_EC_minus_EO_log_spectrum(include,:,:);
dataset.has_paired_conditions = source.has_paired_conditions(include,:);
fields = fieldnames(source.technical);
for i = 1:numel(fields)
    value = source.technical.(fields{i});
    if size(value,1) == n
        dataset.technical.(fields{i}) = value(include,:,:,:,:);
    end
end
dataset.n_validation_participants_read = 0;
end

function folds = local_restrict_outer_rebuild_inner(primary,P,include,cfg)
outer_fold = primary.outer_fold(include,:);
inner_fold = cell(cfg.outer_repeats,cfg.outer_folds);
y = double(string(P.group) == "MDD");
for r = 1:cfg.outer_repeats
    for o = 1:cfg.outer_folds
        test = outer_fold(:,r) == o;
        if numel(unique(y(test))) < 2 || numel(unique(y(~test))) < 2
            error('V371:SensitivityFoldClass', ...
                'Restricted repeat %d outer fold %d lacks a class.',r,o);
        end
        train = find(~test);
        inner_fold{r,o} = v37_make_folds(y(train),P.sex(train),P.age_band(train), ...
            cfg.inner_folds,cfg.random_seed + 1000*r + o);
    end
end
folds = struct('subject_id',string(P.subject_id),'y',y,'outer_fold',outer_fold, ...
    'inner_fold',{inner_fold},'random_seed',cfg.random_seed, ...
    'validation_participants_read',0,'outer_folds_restricted_from_primary',true);
end
