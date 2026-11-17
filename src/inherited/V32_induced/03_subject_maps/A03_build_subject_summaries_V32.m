%% Build recording QC summaries and paired EC-EO maps from V32 outputs.
clear; clc;
pipeline_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root, 'lib'));
cfg = v32_setup();

in_root = fullfile(cfg.output_root, '02_epoch_energy');
status_csv = fullfile(in_root, 'A02_extraction_status.csv');
if ~isfile(status_csv), error('Missing extraction status: %s', status_csv); end
% Explicit delimiter is essential on Windows: automatic detection can mistake
% the many path backslashes for a delimiter and silently corrupt the schema.
extract_status = readtable(status_csv, 'Delimiter', ',', ...
    'VariableNamingRule', 'preserve');
extract_status.subject_id = string(extract_status.subject_id);
extract_status.group = string(extract_status.group);
extract_status.condition = string(extract_status.condition);
extract_status.status = string(extract_status.status);
extract_status.output_file = string(extract_status.output_file);
usable = extract_status(ismember(extract_status.status, ["OK","SKIPPED_EXISTS"]),:);

out_root = fullfile(cfg.output_root, '03_subject_maps');
paired_root = fullfile(out_root, 'paired_EC_minus_EO');
if ~exist(paired_root, 'dir'), mkdir(paired_root); end

summary = table();
for i = 1:height(usable)
    loaded = load(char(usable.output_file(i)), 'result');
    r = loaded.result;
    for b = 1:numel(r.band_names)
        e = double(r.mean_energy(:,b));
        pv = double(r.posterior_variance(:,b));
        row = table(string(r.subject_id), string(r.group), string(r.condition), ...
            string(r.band_names{b}), r.band_limits_hz(b,1), r.band_limits_hz(b,2), ...
            r.n_good_trials, r.inverse_F, r.inverse_R2, r.inverse_VE, ...
            r.sensor_rank, r.sensor_modes, r.temporal_modes, ...
            mean(e), median(e), mean(pv), median(pv), ...
            string(usable.output_file(i)), ...
            'VariableNames', {'subject_id','group','condition','band', ...
            'low_hz','high_hz','n_good_trials','inverse_F','inverse_R2', ...
            'inverse_VE','sensor_rank','sensor_modes','temporal_modes', ...
            'mean_energy_cortex','median_energy_cortex', ...
            'mean_posterior_variance','median_posterior_variance','map_file'});
        summary = [summary; row]; %#ok<AGROW>
    end
end
writetable(summary, fullfile(out_root, 'A03_recording_band_QC.csv'));

subjects = unique(usable.subject_id);
paired_status = table();
for i = 1:numel(subjects)
    sid = subjects(i);
    rows = usable(usable.subject_id == sid,:);
    ec = rows(rows.condition == "restEC",:);
    eo = rows(rows.condition == "restEO",:);
    state = "MISSING_CONDITION";
    output_file = "";
    if height(ec) == 1 && height(eo) == 1
        A = load(char(ec.output_file), 'result');
        B = load(char(eo.output_file), 'result');
        if ~isequal(A.result.band_names, B.result.band_names)
            error('Band mismatch for %s.', sid);
        end
        paired = struct();
        paired.pipeline_version = cfg.pipeline_version;
        paired.subject_id = sid;
        paired.group = string(A.result.group);
        paired.band_names = A.result.band_names;
        paired.band_limits_hz = A.result.band_limits_hz;
        paired.mean_energy_EC_minus_EO = ...
            A.result.mean_energy - B.result.mean_energy;
        paired.log_mean_energy_EC_minus_EO = ...
            A.result.log_mean_energy - B.result.log_mean_energy;
        paired.percentile_EC_minus_EO = ...
            A.result.percentile_log_mean_energy - B.result.percentile_log_mean_energy;
        paired.posterior_variance_EC_minus_EO = ...
            A.result.posterior_variance - B.result.posterior_variance;
        output_file = string(fullfile(paired_root, ...
            char(sid + "_EC_minus_EO_V32.mat")));
        save(char(output_file), 'paired', 'cfg', '-v7.3');
        state = "OK";
    end
    row = table(sid, string(rows.group(1)), state, output_file, ...
        'VariableNames', {'subject_id','group','status','paired_map_file'});
    paired_status = [paired_status; row]; %#ok<AGROW>
end
writetable(paired_status, fullfile(out_root, 'A03_paired_condition_status.csv'));
save(fullfile(out_root, 'A03_subject_summaries.mat'), ...
    'summary', 'paired_status', 'cfg');
