%% Cohort extraction of single-epoch induced posterior source energy.
clear; clc;
pipeline_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root, 'lib'));
cfg = v32_setup();

equivalence_csv = fullfile(cfg.output_root, '01_equivalence_test', ...
    'A01_induced_equivalence_results.csv');
if ~isfile(equivalence_csv)
    error('V32:EquivalenceMissing', ...
        'Run A01_run_induced_equivalence_V32.m before cohort extraction.');
end
eq = readtable(equivalence_csv, 'Delimiter', ',');
if isempty(eq) || ~all(eq.pass)
    error('V32:EquivalenceFailed', 'Equivalence gate has not passed.');
end

out_root = fullfile(cfg.output_root, '02_epoch_energy');
map_root = fullfile(out_root, 'recording_maps');
if ~exist(map_root, 'dir'), mkdir(map_root); end
log_file = fullfile(out_root, 'A02_extraction_log.txt');
if isfile(log_file), delete(log_file); end
diary(log_file);
cleanupObj = onCleanup(@() diary('off'));

inventory = readtable(cfg.inventory_csv, 'Delimiter', ',', ...
    'VariableNamingRule', 'preserve');
inventory.subject_id = string(inventory.subject_id);
inventory.group = string(inventory.group);
inventory.condition = string(inventory.condition);
inventory.source_file = string(inventory.source_file);
inventory.overall_status = string(inventory.overall_status);
if cfg.require_inventory_status_ok
    inventory = inventory(inventory.overall_status == "OK",:);
end
[inventory, duplicate_audit] = v32_resolve_inventory_duplicates(inventory, cfg);
writetable(duplicate_audit, fullfile(out_root, 'A02_duplicate_resolution_audit.csv'));

status = table();
for i = 1:height(inventory)
    subject_id = inventory.subject_id(i);
    group = inventory.group(i);
    condition = inventory.condition(i);
    source_file = inventory.source_file(i);
    safe_id = regexprep(char(subject_id + "_" + group + "_" + condition), '[^A-Za-z0-9_-]', '_');
    output_file = fullfile(map_root, [safe_id '_V32_induced.mat']);
    state = "OK";
    message = "";
    elapsed_seconds = NaN;

    fprintf('\n%03d/%03d %s %s %s\n', i, height(inventory), subject_id, group, condition);
    try
        if cfg.resume && isfile(output_file)
            state = "SKIPPED_EXISTS";
        else
            tick = tic;
            D = spm_eeg_load(char(source_file));
            result = v32_compute_induced_energy(D, cfg);
            result.subject_id = subject_id;
            result.group = group;
            result.condition = condition;
            result.source_file = source_file;
            result.created_utc = string(datetime('now','TimeZone','UTC'));
            result = rmfield(result, 'model');
            save(output_file, 'result', 'cfg', '-v7.3');
            elapsed_seconds = toc(tick);
        end
    catch ME
        state = "FAILED";
        message = string(getReport(ME, 'basic', 'hyperlinks', 'off'));
        fprintf(2, '%s\n', message);
    end

    row = table(subject_id, group, condition, source_file, string(output_file), ...
        state, message, elapsed_seconds, ...
        'VariableNames', {'subject_id','group','condition','source_file', ...
        'output_file','status','error_message','elapsed_seconds'});
    status = [status; row]; %#ok<AGROW>
    writetable(status, fullfile(out_root, 'A02_extraction_status.csv'));
end

save(fullfile(out_root, 'A02_extraction_status.mat'), 'status', 'cfg');
fprintf('\nCompleted: %d OK, %d skipped, %d failed.\n', ...
    sum(status.status == "OK"), sum(status.status == "SKIPPED_EXISTS"), ...
    sum(status.status == "FAILED"));
