%% Build exact SPM IMG 16-mm patches and a template identifiability audit.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'lib'));
cfg = v37_setup();
out = fullfile(cfg.output_root, '01_exact_IMG_patches');
if ~exist(out, 'dir'), mkdir(out); end

old = load(fullfile(cfg.project_root, 'derivatives', ...
    'V34_DCM_aligned_patches', '01_patch_tiling', ...
    'A01_DCM_aligned_16mm_patches.mat'), 'patches');
old = old.patches;
vertices = double(old.vertices);
centres = double(old.centres(:));
npatch = numel(centres);
nvert = size(vertices, 1);
membership = sparse(nvert, npatch);
patch_table = old.patch_table;

for p = 1:npatch
    xyz = vertices(centres(p), :);
    d2 = sum((vertices - xyz).^2, 2);
    ip = find(d2 < cfg.patch_radius_mm^2); % exact strict SPM rule
    if numel(ip) < cfg.regional_spatial_modes
        [~, order] = sort(d2, 'ascend');
        ip = order(1:cfg.regional_spatial_modes); % exact SPM fallback
    end
    membership(ip, p) = 1;
end

patch_table.n_vertices_exact_IMG = full(sum(membership, 1))';
patch_table.maximum_Euclidean_radius_mm = zeros(npatch, 1);
patch_table.cross_hemisphere_fraction = zeros(npatch, 1);
for p = 1:npatch
    ip = find(membership(:,p));
    xyz = vertices(centres(p), :);
    patch_table.maximum_Euclidean_radius_mm(p) = ...
        max(sqrt(sum((vertices(ip,:) - xyz).^2, 2)));
    patch_table.cross_hemisphere_fraction(p) = ...
        mean(string(old.hemisphere(ip)) ~= string(old.hemisphere(centres(p))));
end

% Template lead-field audit using the first frozen discovery recording.
status = v37_discovery_recordings(cfg);
if isempty(status), error('V37:Inventory', 'No discovery recordings.'); end
D = spm_eeg_load(char(status.source_file(1)));
Ic = D.indchantype('EEG', 'GOOD');
[L, D] = spm_eeg_lgainmat(D, [], D.chanlabels(Ic)); %#ok<ASGLU>
L = double(L);
Q = cell(npatch, 1);
mode_rank = zeros(npatch, 1);
effective_rank = zeros(npatch, 1);
for p = 1:npatch
    ip = find(membership(:,p));
    U = spm_svd(L(:,ip)', 0);
    if size(U,2) < cfg.regional_spatial_modes
        error('V37:RegionalRank', 'Patch %d has fewer than six SPM modes.', p);
    end
    U = U(:,1:cfg.regional_spatial_modes);
    G = full(L(:,ip) * U);
    Q{p} = orth(G);
    s = svd(G);
    mode_rank(p) = rank(G);
    effective_rank(p) = local_effective_rank(s);
end
patch_table.template_regional_mode_rank = mode_rank;
patch_table.template_regional_effective_rank = effective_rank;

maximum_canonical_correlation = eye(npatch, 'single');
rms_canonical_correlation = eye(npatch, 'single');
for i = 1:npatch
    for j = i+1:npatch
        s = svd(Q{i}' * Q{j});
        maximum_canonical_correlation(i,j) = single(max(s));
        maximum_canonical_correlation(j,i) = maximum_canonical_correlation(i,j);
        rms_canonical_correlation(i,j) = single(sqrt(mean(s.^2)));
        rms_canonical_correlation(j,i) = rms_canonical_correlation(i,j);
    end
end

patches = struct('vertices', vertices, 'faces', old.faces, ...
    'hemisphere', old.hemisphere, 'centres', centres, ...
    'membership', membership, 'patch_table', patch_table, ...
    'radius_mm', cfg.patch_radius_mm, 'spm_rule', 'Dp < radius^2', ...
    'template_source_file', string(status.source_file(1)), ...
    'maximum_canonical_correlation', maximum_canonical_correlation, ...
    'rms_canonical_correlation', rms_canonical_correlation);
save(fullfile(out, 'A01_exact_SPM_IMG_patch_universe.mat'), ...
    'patches', 'cfg', '-v7.3');
writetable(patch_table, fullfile(out, ...
    'A01_exact_SPM_IMG_patch_centres.csv'));
fprintf('Built %d exact SPM IMG patches and audited %d pairwise subspaces.\n', ...
    npatch, nchoosek(npatch,2));

function r = local_effective_rank(s)
p = (s.^2) / max(sum(s.^2), eps);
r = exp(-sum(p .* log(max(p, eps))));
end
