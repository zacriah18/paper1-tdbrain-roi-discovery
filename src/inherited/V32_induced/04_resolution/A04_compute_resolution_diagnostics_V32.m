%% Matrix-free resolution diagnostics for the saved SPM inverse operators.
clear; clc;
pipeline_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root, 'lib'));
cfg = v32_setup();

inventory = readtable(cfg.inventory_csv, 'Delimiter', ',', ...
    'VariableNamingRule', 'preserve');
inventory.subject_id = string(inventory.subject_id);
inventory.group = string(inventory.group);
inventory.condition = string(inventory.condition);
inventory.source_file = string(inventory.source_file);
inventory.overall_status = string(inventory.overall_status);
inventory = inventory(inventory.overall_status == "OK",:);
[inventory, duplicate_audit] = v32_resolve_inventory_duplicates(inventory, cfg);
inventory = inventory(1:min(height(inventory), cfg.resolution_max_records),:);

out_root = fullfile(cfg.output_root, '04_resolution');
detail_root = fullfile(out_root, 'recording_diagnostics');
if ~exist(detail_root, 'dir'), mkdir(detail_root); end
writetable(duplicate_audit, fullfile(out_root, 'A04_duplicate_resolution_audit.csv'));

summary = table();
for i = 1:height(inventory)
    fprintf('\nResolution %d/%d: %s %s\n', i, height(inventory), ...
        inventory.subject_id(i), inventory.condition(i));
    state = "OK";
    message = "";
    output_file = "";
    try
        D = spm_eeg_load(char(inventory.source_file(i)));
        [model, inverse] = v32_get_inverse(D, cfg.inverse_index);
        M = double(inverse.M);
        L = double(inverse.L);
        vertices = double(model.mesh.tess_mni.vert);
        faces = double(model.mesh.tess_mni.face);
        if size(vertices,1) ~= size(M,1)
            error('Mesh/inverse vertex mismatch.');
        end

        % L*M is only sensor x sensor, but inherits sparse storage from L.
        % Densify this small matrix before SVD; never densify the full
        % vertex-space resolution operator.
        sensor_resolution = full(L*M);
        s = svd(sensor_resolution);
        tolerance = max(size(sensor_resolution))*eps(max(s));
        resolution_rank = sum(s > tolerance);
        resolution_trace = sum(sum(M .* L'));

        graph_model = mesh_graph(vertices, faces);
        seeds = farthest_point_seeds(vertices, cfg.resolution_n_diagnostic_seeds);
        seed_rows = table();
        for k = 1:numel(seeds)
            seed = seeds(k);
            distance = distances(graph_model, seed);
            distance = distance(:);
            psf = abs(M * L(:,seed));
            psf = psf(:);
            ctf = abs((M(seed,:) * L)');
            ctf = ctf(:);
            [~, psf_peak] = max(psf);
            [~, ctf_peak] = max(ctf);
            psf_dispersion = weighted_dispersion(distance, psf.^2);
            ctf_dispersion = weighted_dispersion(distance, ctf.^2);
            psf_radius80 = mass_radius(distance, psf.^2, cfg.resolution_mass_fraction);
            ctf_radius80 = mass_radius(distance, ctf.^2, cfg.resolution_mass_fraction);
            row = table(seed, psf_peak, ctf_peak, distance(psf_peak), ...
                distance(ctf_peak), psf_dispersion, ctf_dispersion, ...
                psf_radius80, ctf_radius80, ...
                'VariableNames', {'seed_vertex','psf_peak_vertex', ...
                'ctf_peak_vertex','psf_peak_displacement_mm', ...
                'ctf_peak_displacement_mm','psf_geodesic_dispersion_mm', ...
                'ctf_geodesic_dispersion_mm','psf_mass_radius_mm', ...
                'ctf_mass_radius_mm'});
            seed_rows = [seed_rows; row]; %#ok<AGROW>
        end

        diagnostics = struct();
        diagnostics.pipeline_version = cfg.pipeline_version;
        diagnostics.subject_id = inventory.subject_id(i);
        diagnostics.group = inventory.group(i);
        diagnostics.condition = inventory.condition(i);
        diagnostics.source_file = inventory.source_file(i);
        diagnostics.resolution_rank = resolution_rank;
        diagnostics.resolution_trace = resolution_trace;
        diagnostics.sensor_resolution_singular_values = s;
        diagnostics.seed_metrics = seed_rows;
        diagnostics.seed_selection = 'MNI Euclidean farthest-point diagnostic sample';
        output_file = string(fullfile(detail_root, char(inventory.subject_id(i) + ...
            "_" + inventory.group(i) + "_" + inventory.condition(i) + ...
            "_resolution_V32.mat")));
        save(char(output_file), 'diagnostics', 'cfg', '-v7.3');

        summary_row = table(inventory.subject_id(i), inventory.group(i), ...
            inventory.condition(i), resolution_rank, resolution_trace, ...
            median(seed_rows.psf_peak_displacement_mm, 'omitnan'), ...
            median(seed_rows.psf_geodesic_dispersion_mm, 'omitnan'), ...
            median(seed_rows.psf_mass_radius_mm, 'omitnan'), state, message, output_file, ...
            'VariableNames', {'subject_id','group','condition','resolution_rank', ...
            'resolution_trace','median_psf_peak_displacement_mm', ...
            'median_psf_geodesic_dispersion_mm','median_psf_mass_radius_mm', ...
            'status','error_message','output_file'});
    catch ME
        state = "FAILED";
        message = string(getReport(ME, 'basic', 'hyperlinks', 'off'));
        message = regexprep(message, '[\r\n]+', ' | ');
        summary_row = table(inventory.subject_id(i), inventory.group(i), ...
            inventory.condition(i), NaN, NaN, NaN, NaN, NaN, state, message, output_file, ...
            'VariableNames', {'subject_id','group','condition','resolution_rank', ...
            'resolution_trace','median_psf_peak_displacement_mm', ...
            'median_psf_geodesic_dispersion_mm','median_psf_mass_radius_mm', ...
            'status','error_message','output_file'});
    end
    summary = [summary; summary_row]; %#ok<AGROW>
    writetable(summary, fullfile(out_root, 'A04_resolution_summary.csv'));
end
save(fullfile(out_root, 'A04_resolution_summary.mat'), 'summary', 'cfg');

function g = mesh_graph(vertices, faces)
edges = [faces(:,[1 2]); faces(:,[2 3]); faces(:,[3 1])];
edges = sort(edges,2);
edges = unique(edges, 'rows');
w = sqrt(sum((vertices(edges(:,1),:) - vertices(edges(:,2),:)).^2,2));
g = graph(edges(:,1), edges(:,2), w, size(vertices,1));
end

function seeds = farthest_point_seeds(vertices, n_seeds)
n = size(vertices,1);
n_seeds = min(n_seeds, n);
[~, first] = max(sum((vertices - mean(vertices,1)).^2,2));
seeds = zeros(n_seeds,1);
seeds(1) = first;
minimum_distance = sqrt(sum((vertices - vertices(first,:)).^2,2));
for i = 2:n_seeds
    [~, seeds(i)] = max(minimum_distance);
    d = sqrt(sum((vertices - vertices(seeds(i),:)).^2,2));
    minimum_distance = min(minimum_distance, d);
end
end

function value = weighted_dispersion(distance, weight)
valid = isfinite(distance) & isfinite(weight) & weight > 0;
if ~any(valid)
    value = NaN;
    return;
end
value = sqrt(sum(weight(valid).*distance(valid).^2)/sum(weight(valid)));
end

function radius = mass_radius(distance, weight, fraction)
valid = isfinite(distance) & isfinite(weight) & weight > 0;
if ~any(valid)
    radius = NaN;
    return;
end
d = distance(valid);
w = weight(valid);
[d, order] = sort(d, 'ascend');
w = w(order);
idx = find(cumsum(w) >= fraction*sum(w), 1, 'first');
if isempty(idx)
    radius = NaN;
else
    radius = d(idx);
end
end
