%% Build and freeze diagnosis-blind, resolution-compatible cortical supports.
clear; clc;
pipeline_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root, 'lib'));
cfg = v32_setup();

out_root = fullfile(cfg.output_root, '07_resolution_supports');
if ~exist(out_root, 'dir'), mkdir(out_root); end
locked_mat = fullfile(out_root, 'A07_frozen_resolution_supports_LOCKED.mat');
if isfile(locked_mat)
    error('V32:SupportsAlreadyFrozen', ...
        'Frozen supports already exist and will not be regenerated: %s', locked_mat);
end

split = readtable(fullfile(cfg.output_root, '05_frozen_split', ...
    'A05_participant_split_LABEL_BLIND.csv'), 'Delimiter', ',');
split.subject_id = string(split.subject_id);
split.assignment = string(split.assignment);
discovery_ids = split.subject_id(split.assignment == "discovery");

S = load(fullfile(cfg.output_root, '06_atlas_scaffold', ...
    'A06_atlas_mesh_scaffold.mat'), 'atlas_scaffold');
scaffold = S.atlas_scaffold;
vertices = double(scaffold.vertices);
faces = double(scaffold.faces);
atlas_index = double(scaffold.atlas_index);
atlas_name = string(scaffold.atlas_name);
hemisphere = string(scaffold.hemisphere);

mesh_graph = make_mesh_graph(vertices, faces);
[initial_id, initial_table] = connected_atlas_components(mesh_graph, ...
    atlas_index, atlas_name, hemisphere, cfg.atlas_min_component_vertices);
n_initial = height(initial_table);
if n_initial < 2
    error('V32:AtlasComponents', 'Too few connected atlas components.');
end

counts = accumarray(initial_id(initial_id>0), 1, [n_initial 1]);
B = sparse(find(initial_id>0), initial_id(initial_id>0), ...
    1./sqrt(counts(initial_id(initial_id>0))), size(vertices,1), n_initial);

inventory = readtable(cfg.inventory_csv, 'Delimiter', ',', ...
    'VariableNamingRule', 'preserve');
inventory.subject_id = string(inventory.subject_id);
inventory.group = string(inventory.group);
inventory.condition = string(inventory.condition);
inventory.source_file = string(inventory.source_file);
inventory.overall_status = string(inventory.overall_status);
inventory = inventory(inventory.overall_status == "OK",:);
[inventory, ~] = v32_resolve_inventory_duplicates(inventory, cfg);
inventory = inventory(ismember(inventory.subject_id, discovery_ids),:);
% Diagnosis is intentionally dropped before profile construction.
inventory = inventory(:, {'subject_id','condition','source_file'});

mean_psf = zeros(n_initial,n_initial);
mean_ctf = zeros(n_initial,n_initial);
n_profiles = 0;
profile_audit = table();
for i = 1:height(inventory)
    fprintf('Profile %d/%d: %s %s\n', i, height(inventory), ...
        inventory.subject_id(i), inventory.condition(i));
    state = "OK"; message = "";
    try
        D = spm_eeg_load(char(inventory.source_file(i)));
        [~, inverse] = v32_get_inverse(D, cfg.inverse_index);
        M = double(inverse.M);
        L = double(inverse.L);
        A = full((B'*M) * (L*B));
        psf = normalize_columns(abs(A));
        ctf = normalize_columns(abs(A'));
        mean_psf = mean_psf + psf;
        mean_ctf = mean_ctf + ctf;
        n_profiles = n_profiles + 1;
    catch ME
        state = "FAILED";
        message = regexprep(string(getReport(ME,'basic','hyperlinks','off')), ...
            '[\r\n]+', ' | ');
    end
    row = table(inventory.subject_id(i), inventory.condition(i), state, message, ...
        'VariableNames', {'subject_id','condition','status','error_message'});
    profile_audit = [profile_audit; row]; %#ok<AGROW>
end
if n_profiles == 0 || any(profile_audit.status == "FAILED")
    error('V32:ProfileFailure', '%d/%d discovery profiles failed.', ...
        sum(profile_audit.status == "FAILED"), height(profile_audit));
end
mean_psf = mean_psf/n_profiles;
mean_ctf = mean_ctf/n_profiles;

resolution = readtable(fullfile(cfg.output_root, '04_resolution', ...
    'A04_resolution_summary.csv'), 'Delimiter', ',');
resolution.subject_id = string(resolution.subject_id);
resolution.status = string(resolution.status);
resolution = resolution(resolution.status == "OK" & ...
    ismember(resolution.subject_id, discovery_ids),:);
median_rank = median(resolution.resolution_rank, 'omitnan');
target_supports = max(2*cfg.support_min_count_per_hemisphere, ...
    floor(cfg.support_rank_fraction*median_rank));
target_supports = min(target_supports, n_initial);

initial_adjacency = parcel_adjacency(faces, initial_id, n_initial);
[membership, merge_history] = merge_by_resolution_profiles(mean_psf, ...
    mean_ctf, initial_adjacency, initial_table.hemisphere, counts, ...
    target_supports, cfg.support_min_count_per_hemisphere);

support_id = zeros(size(initial_id));
for i = 1:n_initial
    support_id(initial_id == i) = membership(i);
end
support_id = relabel_consecutive(support_id);
n_supports = max(support_id);

support_table = summarize_supports(support_id, vertices, atlas_index, ...
    atlas_name, hemisphere);
for i = 1:n_supports
    rows = find(support_id == i);
    if max(conncomp(subgraph(mesh_graph, rows))) ~= 1
        error('V32:DisconnectedSupport', 'Support %d is not mesh connected.', i);
    end
end

frozen = struct();
frozen.pipeline_version = cfg.pipeline_version;
frozen.created = datetime('now');
frozen.method = ['Diagnosis-blind adjacent agglomeration of connected ' ...
    'Neuromorphometrics components using discovery-average normalized ' ...
    'parcel PSF/CTF cosine similarity'];
frozen.discovery_participants = discovery_ids;
frozen.n_discovery_recordings = n_profiles;
frozen.discovery_median_resolution_rank = median_rank;
frozen.target_supports = target_supports;
frozen.final_supports = n_supports;
frozen.initial_component_id = initial_id;
frozen.support_id = support_id;
frozen.initial_components = initial_table;
frozen.support_table = support_table;
frozen.mean_psf = mean_psf;
frozen.mean_ctf = mean_ctf;
frozen.merge_history = merge_history;
frozen.vertices = vertices;
frozen.faces = faces;

save(locked_mat, 'frozen', 'profile_audit', 'cfg', '-v7.3');
writetable(profile_audit, fullfile(out_root, 'A07_profile_construction_audit.csv'));
writetable(initial_table, fullfile(out_root, 'A07_initial_connected_components.csv'));
writetable(merge_history, fullfile(out_root, 'A07_merge_history.csv'));
writetable(support_table, fullfile(out_root, 'A07_frozen_support_summary.csv'));
vertex_output = table((1:numel(support_id))', support_id, initial_id, ...
    atlas_index, atlas_name, hemisphere, ...
    'VariableNames', {'vertex','support_id','initial_component_id', ...
    'atlas_index','atlas_name','hemisphere'});
writetable(vertex_output, fullfile(out_root, 'A07_frozen_support_vertices.csv'));
fprintf('Frozen %d connected supports from %d atlas components using %d discovery recordings.\n', ...
    n_supports, n_initial, n_profiles);

function g = make_mesh_graph(vertices, faces)
edges = [faces(:,[1 2]); faces(:,[2 3]); faces(:,[3 1])];
edges = unique(sort(edges,2),'rows');
w = sqrt(sum((vertices(edges(:,1),:) - vertices(edges(:,2),:)).^2,2));
g = graph(edges(:,1),edges(:,2),w,size(vertices,1));
end

function [component_id, T] = connected_atlas_components(g, index, name, hemi, min_size)
component_id = zeros(size(index));
T = table(); next = 0;
labels = unique(index(index>0));
for i = 1:numel(labels)
    rows = find(index == labels(i));
    bins = conncomp(subgraph(g,rows));
    for b = unique(bins)
        member = rows(bins == b);
        if numel(member) < min_size, continue; end
        next = next + 1;
        component_id(member) = next;
        row = table(next, labels(i), name(member(1)), hemi(member(1)), ...
            numel(member), 'VariableNames', {'initial_component_id', ...
            'atlas_index','atlas_name','hemisphere','n_vertices'});
        T = [T; row]; %#ok<AGROW>
    end
end
end

function X = normalize_columns(X)
scale = sqrt(sum(X.^2,1));
scale(scale==0) = 1;
X = X./scale;
end

function A = parcel_adjacency(faces, id, n)
edges = [faces(:,[1 2]); faces(:,[2 3]); faces(:,[3 1])];
pairs = [id(edges(:,1)) id(edges(:,2))];
pairs = pairs(all(pairs>0,2) & pairs(:,1)~=pairs(:,2),:);
pairs = unique(sort(pairs,2),'rows');
A = sparse(pairs(:,1),pairs(:,2),true,n,n);
A = A | A';
end

function [membership, history] = merge_by_resolution_profiles(psf,ctf,adj,hemi,weight,target,min_hemi)
n = size(psf,1); membership = (1:n)'; history = table(); step = 0;
while numel(unique(membership)) > target
    clusters = unique(membership);
    best = [-Inf NaN NaN];
    hemi_counts = [sum(arrayfun(@(c) hemi(find(membership==c,1))=="left",clusters)), ...
        sum(arrayfun(@(c) hemi(find(membership==c,1))=="right",clusters))];
    for a = 1:numel(clusters)
        ia = find(membership==clusters(a));
        ha = hemi(ia(1));
        if ha=="left" && hemi_counts(1)<=min_hemi, continue; end
        if ha=="right" && hemi_counts(2)<=min_hemi, continue; end
        for b = a+1:numel(clusters)
            ib = find(membership==clusters(b));
            if hemi(ib(1)) ~= ha || ~any(any(adj(ia,ib))), continue; end
            pa = cluster_profile(psf,ctf,ia,weight);
            pb = cluster_profile(psf,ctf,ib,weight);
            similarity = dot(pa,pb)/(norm(pa)*norm(pb)+eps);
            if similarity > best(1), best=[similarity clusters(a) clusters(b)]; end
        end
    end
    if ~isfinite(best(1)), error('V32:MergeStalled','No eligible adjacent merge remains.'); end
    step=step+1; membership(membership==best(3))=best(2);
    row=table(step,best(2),best(3),best(1),numel(unique(membership)), ...
        'VariableNames',{'step','kept_cluster','merged_cluster','profile_cosine','supports_remaining'});
    history=[history;row]; %#ok<AGROW>
end
membership = relabel_consecutive(membership);
end

function p = cluster_profile(psf,ctf,members,weight)
w=weight(members); w=w/sum(w);
p=[psf(:,members)*w; ctf(:,members)*w];
end

function id = relabel_consecutive(id)
u=unique(id(id>0));
for i=1:numel(u), id(id==u(i))=i; end
end

function T = summarize_supports(id,vertices,index,name,hemi)
T=table();
for s=1:max(id)
    rows=find(id==s); centroid=mean(vertices(rows,:),1);
    [~,local]=min(sum((vertices(rows,:)-centroid).^2,2)); rep=rows(local);
    labs=unique(index(rows)); labs=labs(labs>0); descriptions=strings(numel(labs),1);
    proportions=zeros(numel(labs),1);
    for j=1:numel(labs)
        descriptions(j)=name(find(index==labs(j),1));
        proportions(j)=mean(index(rows)==labs(j));
    end
    [proportions,order]=sort(proportions,'descend'); descriptions=descriptions(order);
    overlap=strjoin(descriptions+"="+compose('%.3f',proportions),'; ');
    row=table(s,hemi(rows(1)),numel(rows),centroid(1),centroid(2),centroid(3), ...
        rep,vertices(rep,1),vertices(rep,2),vertices(rep,3),overlap, ...
        'VariableNames',{'support_id','hemisphere','n_vertices','centroid_x', ...
        'centroid_y','centroid_z','representative_vertex','representative_x', ...
        'representative_y','representative_z','atlas_overlap'});
    T=[T;row]; %#ok<AGROW>
end
end
