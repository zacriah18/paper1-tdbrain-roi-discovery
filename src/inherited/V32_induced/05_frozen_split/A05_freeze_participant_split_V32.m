%% Freeze a participant-level discovery/validation split before ROI discovery.
clear; clc;
pipeline_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root, 'lib'));
cfg = v32_setup();

out_root = fullfile(cfg.output_root, '05_frozen_split');
if ~exist(out_root, 'dir'), mkdir(out_root); end
locked_csv = fullfile(out_root, 'A05_participant_split_LOCKED.csv');
blind_csv = fullfile(out_root, 'A05_participant_split_LABEL_BLIND.csv');
locked_mat = fullfile(out_root, 'A05_participant_split_LOCKED.mat');
if isfile(locked_csv) || isfile(locked_mat)
    error('V32:SplitAlreadyFrozen', ...
        'Locked split already exists. It will not be regenerated: %s', locked_csv);
end

paired_csv = fullfile(cfg.output_root, '03_subject_maps', ...
    'A03_paired_condition_status.csv');
participants = readtable(paired_csv, 'Delimiter', ',', ...
    'VariableNamingRule', 'preserve');
participants.subject_id = string(participants.subject_id);
participants.group = string(participants.group);
participants.status = string(participants.status);

metadata = readtable(cfg.metadata_xlsx, 'Sheet', 'TDBRAIN-V3', ...
    'VariableNamingRule', 'preserve', 'TextType', 'string');
metadata.TDBRAIN_ID = string(metadata.TDBRAIN_ID);
[matched, location] = ismember(participants.subject_id, metadata.TDBRAIN_ID);
if ~all(matched)
    error('V32:MissingMetadata', 'Metadata missing for %d participants.', sum(~matched));
end
metadata = metadata(location,:);

age = double(metadata.age);
sex = string(metadata.gender);
if any(~isfinite(age)) || any(ismissing(sex))
    error('V32:IncompleteSplitMetadata', ...
        'Age/sex is incomplete; do not silently weaken split stratification.');
end
age_band = discretize(age, cfg.age_band_edges, ...
    'categorical', {'18-29','30-44','45-59','60+'});
availability = repmat("single_condition", height(participants), 1);
availability(participants.status == "OK") = "paired_EC_EO";
stratum = participants.group + "|sex=" + sex + "|age=" + ...
    string(age_band) + "|" + availability;

rng(cfg.random_seed, 'twister');
assignment = strings(height(participants),1);
unique_strata = unique(stratum, 'sorted');
for i = 1:numel(unique_strata)
    rows = find(stratum == unique_strata(i));
    rows = rows(randperm(numel(rows)));
    n_discovery = round(cfg.discovery_fraction*numel(rows));
    if numel(rows) >= 2
        n_discovery = min(max(n_discovery,1),numel(rows)-1);
    else
        n_discovery = 1;
    end
    assignment(rows(1:n_discovery)) = "discovery";
    assignment(rows(n_discovery+1:end)) = "validation";
end

split = table(participants.subject_id, participants.group, age, sex, ...
    string(age_band), availability, stratum, assignment, ...
    repmat(cfg.random_seed,height(participants),1), ...
    'VariableNames', {'subject_id','group','age','sex','age_band', ...
    'condition_availability','stratum','assignment','random_seed'});
split = sortrows(split, 'subject_id');
writetable(split, locked_csv);
label_blind = split(:, {'subject_id','age','sex','age_band', ...
    'condition_availability','assignment','random_seed'});
writetable(label_blind, blind_csv);
save(locked_mat, 'split', 'label_blind', 'cfg');

balance = groupsummary(split, {'assignment','group','sex','age_band', ...
    'condition_availability'});
writetable(balance, fullfile(out_root, 'A05_split_balance_audit.csv'));
fprintf('Frozen split: %d discovery, %d validation participants.\n', ...
    sum(split.assignment == "discovery"), sum(split.assignment == "validation"));
