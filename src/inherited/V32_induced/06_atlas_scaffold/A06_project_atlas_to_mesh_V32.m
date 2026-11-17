%% Project the SPM Neuromorphometrics cortical atlas to the canonical mesh.
clear; clc;
pipeline_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root, 'lib'));
cfg = v32_setup();

out_root = fullfile(cfg.output_root, '06_atlas_scaffold');
if ~exist(out_root, 'dir'), mkdir(out_root); end

inventory = readtable(cfg.inventory_csv, 'Delimiter', ',', ...
    'VariableNamingRule', 'preserve');
inventory.subject_id = string(inventory.subject_id);
inventory.group = string(inventory.group);
inventory.condition = string(inventory.condition);
inventory.source_file = string(inventory.source_file);
inventory.overall_status = string(inventory.overall_status);
inventory = inventory(inventory.overall_status == "OK",:);
[inventory, ~] = v32_resolve_inventory_duplicates(inventory, cfg);
D = spm_eeg_load(char(inventory.source_file(1)));
[model, ~] = v32_get_inverse(D, cfg.inverse_index);
vertices = double(model.mesh.tess_mni.vert);
faces = double(model.mesh.tess_mni.face);

atlas = spm_atlas('load', cfg.atlas_xml);
volume = spm_read_vols(atlas.VA);
cortical_indices = [atlas.labels.index];
cortical_indices = cortical_indices(cortical_indices >= cfg.atlas_cortical_min_index);
cortical_mask = ismember(volume, cortical_indices);

voxel = atlas.VA.mat \ [vertices'; ones(1,size(vertices,1))];
direct_label = round(spm_sample_vol(atlas.VA, voxel(1,:), voxel(2,:), voxel(3,:), 0))';
direct_label(~ismember(direct_label, cortical_indices)) = 0;
atlas_index = direct_label;
projection_distance_mm = zeros(size(atlas_index));

unassigned = find(atlas_index == 0);
[ci,cj,ck] = ind2sub(size(volume), find(cortical_mask));
cortical_vox = [ci'; cj'; ck'; ones(1,numel(ci))];
cortical_xyz = (atlas.VA.mat*cortical_vox)';
cortical_xyz = cortical_xyz(:,1:3);
cortical_value = volume(cortical_mask);
if ~isempty(unassigned)
    [nearest, distance] = knnsearch(cortical_xyz, vertices(unassigned,:));
    accept = distance <= cfg.atlas_projection_max_mm;
    atlas_index(unassigned(accept)) = cortical_value(nearest(accept));
    projection_distance_mm(unassigned(accept)) = distance(accept);
    projection_distance_mm(unassigned(~accept)) = NaN;
end

atlas_name = repmat("Unassigned", size(atlas_index));
hemisphere = repmat("unknown", size(atlas_index));
for i = 1:numel(atlas.labels)
    hit = atlas_index == atlas.labels(i).index;
    atlas_name(hit) = string(atlas.labels(i).name);
end
hemisphere(startsWith(atlas_name,"Left ")) = "left";
hemisphere(startsWith(atlas_name,"Right ")) = "right";

% Hemisphere inconsistency indicates projection across the medial plane.
inconsistent = (vertices(:,1) < -1 & hemisphere == "right") | ...
    (vertices(:,1) > 1 & hemisphere == "left");
atlas_index(inconsistent) = 0;
atlas_name(inconsistent) = "Unassigned";
hemisphere(inconsistent) = "unknown";

vertex_table = table((1:size(vertices,1))', vertices(:,1), vertices(:,2), ...
    vertices(:,3), atlas_index, atlas_name, hemisphere, projection_distance_mm, ...
    'VariableNames', {'vertex','x','y','z','atlas_index','atlas_name', ...
    'hemisphere','projection_distance_mm'});
assigned = vertex_table(vertex_table.atlas_index > 0,:);
group_vars = {'atlas_index','atlas_name','hemisphere'};
label_summary = groupsummary(assigned, group_vars);
distance_summary = groupsummary(assigned, group_vars, 'median', ...
    'projection_distance_mm');
label_summary.median_projection_distance_mm = ...
    distance_summary.median_projection_distance_mm;

atlas_scaffold = struct('pipeline_version',cfg.pipeline_version, ...
    'atlas_xml',cfg.atlas_xml,'vertices',vertices,'faces',faces, ...
    'atlas_index',atlas_index,'atlas_name',atlas_name, ...
    'hemisphere',hemisphere,'projection_distance_mm',projection_distance_mm);
save(fullfile(out_root, 'A06_atlas_mesh_scaffold.mat'), ...
    'atlas_scaffold', 'vertex_table', 'label_summary', 'cfg', '-v7.3');
writetable(vertex_table, fullfile(out_root, 'A06_atlas_vertex_assignments.csv'));
writetable(label_summary, fullfile(out_root, 'A06_atlas_label_summary.csv'));
fprintf('Atlas coverage: %d/%d vertices (%.1f%%), %d cortical labels.\n', ...
    sum(atlas_index>0), numel(atlas_index), 100*mean(atlas_index>0), ...
    numel(unique(atlas_index(atlas_index>0))));
