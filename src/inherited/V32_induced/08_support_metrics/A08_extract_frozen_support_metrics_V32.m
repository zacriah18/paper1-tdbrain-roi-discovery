%% Apply frozen supports to recording and paired-condition source maps.
clear; clc;
pipeline_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root, 'lib'));
cfg = v32_setup();

out_root = fullfile(cfg.output_root, '08_support_metrics');
if ~exist(out_root, 'dir'), mkdir(out_root); end

F = load(fullfile(cfg.output_root, '07_resolution_supports', ...
    'A07_frozen_resolution_supports_LOCKED.mat'), 'frozen');
support_id = double(F.frozen.support_id);
support_table = F.frozen.support_table;
n_supports = height(support_table);

split = readtable(fullfile(cfg.output_root, '05_frozen_split', ...
    'A05_participant_split_LOCKED.csv'), 'Delimiter', ',');
split.subject_id = string(split.subject_id);
split.group = string(split.group);
split.assignment = string(split.assignment);

status = readtable(fullfile(cfg.output_root, '02_epoch_energy', ...
    'A02_extraction_status.csv'), 'Delimiter', ',');
status.subject_id = string(status.subject_id);
status.group = string(status.group);
status.condition = string(status.condition);
status.output_file = string(status.output_file);
status.status = string(status.status);
status = status(ismember(status.status,["OK","SKIPPED_EXISTS"]),:);

example = load(char(status.output_file(1)), 'result');
n_bands = numel(example.result.band_names);
n_rows = height(status)*n_bands*n_supports;
subject_id = strings(n_rows,1); group = strings(n_rows,1);
condition = strings(n_rows,1); assignment = strings(n_rows,1);
band = strings(n_rows,1); support = zeros(n_rows,1);
mean_percentile = nan(n_rows,1); median_percentile = nan(n_rows,1);
mean_log_energy = nan(n_rows,1); median_log_energy = nan(n_rows,1);
mean_posterior_variance = nan(n_rows,1); n_vertices = zeros(n_rows,1);
cursor = 0;

for i = 1:height(status)
    fprintf('Support metrics %d/%d: %s %s\n', i, height(status), ...
        status.subject_id(i), status.condition(i));
    loaded = load(char(status.output_file(i)), 'result');
    r = loaded.result;
    split_row = find(split.subject_id == status.subject_id(i),1);
    if isempty(split_row), error('Missing frozen split for %s.',status.subject_id(i)); end
    for b = 1:n_bands
        for s = 1:n_supports
            cursor = cursor + 1;
            vertices = support_id == s;
            subject_id(cursor) = status.subject_id(i);
            group(cursor) = status.group(i);
            condition(cursor) = status.condition(i);
            assignment(cursor) = split.assignment(split_row);
            band(cursor) = string(r.band_names{b});
            support(cursor) = s;
            p = double(r.percentile_log_mean_energy(vertices,b));
            le = double(r.log_mean_energy(vertices,b));
            pv = double(r.posterior_variance(vertices,b));
            mean_percentile(cursor) = mean(p,'omitnan');
            median_percentile(cursor) = median(p,'omitnan');
            mean_log_energy(cursor) = mean(le,'omitnan');
            median_log_energy(cursor) = median(le,'omitnan');
            mean_posterior_variance(cursor) = mean(pv,'omitnan');
            n_vertices(cursor) = sum(vertices);
        end
    end
end

recording_metrics = table(subject_id,group,condition,assignment,band,support, ...
    n_vertices,mean_percentile,median_percentile,mean_log_energy, ...
    median_log_energy,mean_posterior_variance, ...
    'VariableNames', {'subject_id','group','condition','assignment','band', ...
    'support_id','n_vertices','mean_percentile_log_energy', ...
    'median_percentile_log_energy','mean_log_energy','median_log_energy', ...
    'mean_posterior_variance'});
writetable(recording_metrics, fullfile(out_root, ...
    'A08_frozen_support_recording_metrics.csv'));
blind_discovery = recording_metrics(recording_metrics.assignment=="discovery",:);
blind_discovery.group = [];
writetable(blind_discovery, fullfile(out_root, ...
    'A08_discovery_metrics_LABEL_BLIND.csv'));

paired_status = readtable(fullfile(cfg.output_root, '03_subject_maps', ...
    'A03_paired_condition_status.csv'), 'Delimiter', ',');
paired_status.subject_id = string(paired_status.subject_id);
paired_status.group = string(paired_status.group);
paired_status.status = string(paired_status.status);
paired_status.paired_map_file = string(paired_status.paired_map_file);
paired_status = paired_status(paired_status.status=="OK",:);

n_paired_rows = height(paired_status)*n_bands*n_supports;
psubject = strings(n_paired_rows,1); pgroup = strings(n_paired_rows,1);
passignment = strings(n_paired_rows,1); pband = strings(n_paired_rows,1);
psupport = zeros(n_paired_rows,1); pnvertices = zeros(n_paired_rows,1);
pmean = nan(n_paired_rows,1); pmedian = nan(n_paired_rows,1);
cursor = 0;
for i = 1:height(paired_status)
    loaded = load(char(paired_status.paired_map_file(i)), 'paired');
    p = loaded.paired;
    split_row = find(split.subject_id == paired_status.subject_id(i),1);
    for b = 1:n_bands
        for s = 1:n_supports
            cursor=cursor+1; vertices=support_id==s;
            values=double(p.percentile_EC_minus_EO(vertices,b));
            psubject(cursor)=paired_status.subject_id(i);
            pgroup(cursor)=paired_status.group(i);
            passignment(cursor)=split.assignment(split_row);
            pband(cursor)=string(p.band_names{b}); psupport(cursor)=s;
            pnvertices(cursor)=sum(vertices);
            pmean(cursor)=mean(values,'omitnan');
            pmedian(cursor)=median(values,'omitnan');
        end
    end
end
paired_metrics=table(psubject,pgroup,passignment,pband,psupport,pnvertices, ...
    pmean,pmedian,'VariableNames',{'subject_id','group','assignment','band', ...
    'support_id','n_vertices','mean_percentile_EC_minus_EO', ...
    'median_percentile_EC_minus_EO'});
writetable(paired_metrics, fullfile(out_root, ...
    'A08_frozen_support_paired_metrics.csv'));
save(fullfile(out_root,'A08_frozen_support_metrics.mat'), ...
    'recording_metrics','paired_metrics','support_table','cfg','-v7.3');
fprintf('Wrote %d recording rows and %d paired rows across %d frozen supports.\n', ...
    height(recording_metrics),height(paired_metrics),n_supports);
