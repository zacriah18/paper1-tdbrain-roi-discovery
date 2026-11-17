function region = v37_exact_img_filters(D, cfg, patches)
%V37_EXACT_IMG_FILTERS Exact SPM IMG bases projected through the saved inverse.
[~, inverse] = v32_get_inverse(D, cfg.inverse_index);
Ic_dcm = D.indchantype('EEG', 'GOOD');
[L, D] = spm_eeg_lgainmat(D, [], D.chanlabels(Ic_dcm)); %#ok<ASGLU>
L = double(L);
Uinv = inverse.U;
if ~iscell(Uinv), Uinv = {Uinv}; end
Ic_inv = inverse.Ic;
if ~iscell(Ic_inv), Ic_inv = {Ic_inv}; end

npatch = size(patches.membership, 2);
nm = cfg.regional_spatial_modes;
filters = zeros(npatch * nm, numel(Ic_inv{1}));
regional_rank = zeros(npatch, 1);
regional_effective_rank = zeros(npatch, 1);
filter_norm = zeros(npatch, 1);
posterior_variance = nan(npatch, 1);

for p = 1:npatch
    ip = find(patches.membership(:,p));
    Us = spm_svd(L(:,ip)', 0);
    if size(Us,2) < nm
        error('V37:RegionalModes', ...
            'Patch %d has only %d lead-field modes.', p, size(Us,2));
    end
    Us = Us(:,1:nm);
    G = full(L(:,ip) * Us);
    rows = (p-1)*nm + (1:nm);
    filters(rows,:) = (Us' * double(inverse.M(ip,:))) * double(Uinv{1});
    s = svd(G);
    regional_rank(p) = rank(G);
    q = (s.^2) / max(sum(s.^2), eps);
    regional_effective_rank(p) = exp(-sum(q .* log(max(q,eps))));
    filter_norm(p) = norm(filters(rows,:), 'fro');
    if isfield(inverse, 'qC') && numel(inverse.qC) >= max(ip)
        posterior_variance(p) = mean(double(inverse.qC(ip)), 'omitnan');
    end
end

region = struct('filters', filters, 'regional_rank', regional_rank, ...
    'regional_effective_rank', regional_effective_rank, ...
    'filter_norm', filter_norm, ...
    'mean_posterior_variance', posterior_variance, ...
    'inverse', inverse, 'inverse_channels', Ic_inv{1}, ...
    'dcm_channels', Ic_dcm);
end
