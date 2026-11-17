%% Extract exact-IMG regional spectral features from discovery recordings.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'lib'));
cfg = v37_setup();
out = fullfile(cfg.output_root, '02_node_features');
maps_dir = fullfile(out, 'maps');
if ~exist(maps_dir, 'dir'), mkdir(maps_dir); end

P = load(fullfile(cfg.output_root, '01_exact_IMG_patches', ...
    'A01_exact_SPM_IMG_patch_universe.mat'), 'patches');
patches = P.patches;
status = v37_discovery_recordings(cfg);
n = height(status);
run_status = status(:, {'subject_id','group','condition','source_file'});
run_status.output_file = strings(n,1);
run_status.status = repmat("PENDING",n,1);
run_status.message = strings(n,1);
run_status.elapsed_seconds = nan(n,1);

for r = 1:n
    tic;
    basename = status.subject_id(r) + "_" + status.group(r) + "_" + ...
        status.condition(r) + "_V37_node_spectra.mat";
    output_file = fullfile(maps_dir, char(basename));
    run_status.output_file(r) = string(output_file);
    if cfg.resume && exist(output_file, 'file')
        run_status.status(r) = "SKIPPED_EXISTS";
        run_status.elapsed_seconds(r) = toc;
        continue
    end
    try
        D = spm_eeg_load(char(status.source_file(r)));
        region = v37_exact_img_filters(D, cfg, patches);
        spectral = v37_regional_spectra(D, cfg, region);
        result = struct('pipeline_version', cfg.pipeline_version, ...
            'subject_id', status.subject_id(r), 'group', status.group(r), ...
            'condition', status.condition(r), ...
            'source_file', status.source_file(r), ...
            'patch_id', (1:size(patches.membership,2))', ...
            'spectral', spectral, ...
            'regional_rank', region.regional_rank, ...
            'regional_effective_rank', region.regional_effective_rank, ...
            'filter_norm', region.filter_norm, ...
            'mean_posterior_variance', region.mean_posterior_variance, ...
            'feature_role', "DCM-concordant neural discovery; technical QC separate");
        save(output_file, 'result', 'cfg', '-v7.3');
        run_status.status(r) = "OK";
    catch ME
        run_status.status(r) = "ERROR";
        run_status.message(r) = string(ME.identifier) + ": " + string(ME.message);
    end
    run_status.elapsed_seconds(r) = toc;
    writetable(run_status, fullfile(out, 'A02_node_feature_extraction_status.csv'));
    fprintf('%d/%d %s %s %s (%.1fs)\n', r, n, status.subject_id(r), ...
        status.condition(r), run_status.status(r), run_status.elapsed_seconds(r));
end
writetable(run_status, fullfile(out, 'A02_node_feature_extraction_status.csv'));
save(fullfile(out, 'A02_node_feature_extraction_status.mat'), ...
    'run_status', 'cfg', '-v7.3');
