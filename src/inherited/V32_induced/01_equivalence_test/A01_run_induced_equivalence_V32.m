%% Validate V32 streaming energy against SPM's native induced route.
clear; clc;
pipeline_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root, 'lib'));
cfg = v32_setup();

out_root = fullfile(cfg.output_root, '01_equivalence_test');
if ~exist(out_root, 'dir'), mkdir(out_root); end
log_file = fullfile(out_root, 'A01_equivalence_log.txt');
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
keep = inventory.overall_status == "OK" & ...
    ismember(inventory.subject_id, string(cfg.equivalence_subject_ids)) & ...
    ismember(inventory.condition, string(cfg.equivalence_conditions));
test_rows = inventory(keep,:);
if isempty(test_rows)
    error('V32:NoEquivalenceRows', 'No configured equivalence recordings were found.');
end

rows = table();
for i = 1:height(test_rows)
    fprintf('\nEquivalence %d/%d: %s %s\n', i, height(test_rows), ...
        test_rows.subject_id(i), test_rows.condition(i));
    D = spm_eeg_load(char(test_rows.source_file(i)));
    custom = v32_compute_induced_energy(D, cfg);

    for b = 1:numel(custom.band_names)
        Dnative = D;
        Dnative.val = cfg.inverse_index;
        Dnative.inv{cfg.inverse_index}.contrast.woi = custom.time_window_ms;
        Dnative.inv{cfg.inverse_index}.contrast.fboi = custom.band_limits_hz(b,:);
        Dnative.inv{cfg.inverse_index}.contrast.type = 'induced';
        Dnative.inv{cfg.inverse_index}.contrast.display = 0;
        Dnative = spm_eeg_inv_results(Dnative);
        native = double(Dnative.inv{cfg.inverse_index}.contrast.GW{1});
        observed = double(custom.expected_energy(:,b));

        delta = observed - native;
        max_abs = max(abs(delta));
        denom = max(abs(native), eps);
        max_rel = max(abs(delta)./denom);
        pearson_r = local_corr(observed, native);
        pass = max_abs <= cfg.equivalence_abs_tolerance || ...
            (max_rel <= cfg.equivalence_rel_tolerance && ...
             pearson_r >= cfg.equivalence_min_correlation);

        row = table(test_rows.subject_id(i), test_rows.group(i), ...
            test_rows.condition(i), string(custom.band_names{b}), ...
            custom.band_limits_hz(b,1), custom.band_limits_hz(b,2), ...
            custom.n_good_trials, max_abs, max_rel, pearson_r, pass, ...
            'VariableNames', {'subject_id','group','condition','band', ...
            'low_hz','high_hz','n_good_trials','max_abs_error', ...
            'max_relative_error','pearson_r','pass'});
        rows = [rows; row]; %#ok<AGROW>
        fprintf('%s: max abs %.3g | max rel %.3g | r %.12f | pass %d\n', ...
            custom.band_names{b}, max_abs, max_rel, pearson_r, pass);
    end
end

writetable(rows, fullfile(out_root, 'A01_induced_equivalence_results.csv'));
save(fullfile(out_root, 'A01_induced_equivalence_results.mat'), 'rows', 'cfg');
if ~all(rows.pass)
    error('V32:EquivalenceFailed', ...
        'At least one SPM induced equivalence comparison failed.');
end
fprintf('\nAll %d comparisons passed.\n', height(rows));

function r = local_corr(x,y)
x = x(:) - mean(x(:));
y = y(:) - mean(y(:));
r = (x'*y) / sqrt((x'*x)*(y'*y));
end
