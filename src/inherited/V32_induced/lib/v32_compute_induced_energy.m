function result = v32_compute_induced_energy(D, cfg)
%V32_COMPUTE_INDUCED_ENERGY Stream SPM-equivalent induced source energy.
%
% The implementation follows spm_eeg_inv_results(type='induced'):
%   Y = D(Ic,It,trial)*TTW; Y = U*Y*scale; MYW = M*Y;
%   mean_energy = mean_trial sum(MYW.^2,2)
% Posterior conditional variance is retained separately. expected_energy is
% mean_energy + posterior_variance and should equal SPM contrast.GW.

[model, inverse, val] = v32_get_inverse(D, cfg.inverse_index);

band_names = cfg.band_names;
band_limits = cfg.band_limits_hz;
if cfg.include_secondary_bands
    band_names = [band_names cfg.secondary_band_names];
    band_limits = [band_limits; cfg.secondary_band_limits_hz];
end
n_bands = numel(band_names);
n_vertices = size(inverse.M, 1);

if n_vertices ~= cfg.expected_vertices
    error('V32:VertexCount', 'Expected %d vertices, found %d.', ...
        cfg.expected_vertices, n_vertices);
end

try
    trial_labels = inverse.trials;
catch
    trial_labels = D.condlist;
end
if ischar(trial_labels) || isstring(trial_labels)
    trial_labels = cellstr(trial_labels);
end
if numel(trial_labels) ~= 1
    error('V32:ConditionCount', ...
        'V32 expects one condition per source file; found %d.', numel(trial_labels));
end

good_trials = D.indtrial(trial_labels{1}, 'GOOD');
n_trials = numel(good_trials);
if n_trials < cfg.minimum_good_epochs
    error('V32:TooFewEpochs', 'Only %d good epochs; minimum is %d.', ...
        n_trials, cfg.minimum_good_epochs);
end

U = inverse.U;
Ic = inverse.Ic;
It = inverse.It;
if ~iscell(U), U = {U}; end
if ~iscell(Ic), Ic = {Ic}; end
if numel(U) ~= 1 || numel(Ic) ~= 1 || strcmp(D.modality(1,1), 'Multimodal')
    error('V32:Modality', 'Current V32 implementation supports unimodal EEG only.');
end

try
    scale = inverse.scale;
catch
    scale = 1;
end
if numel(scale) > 1, scale = scale(1); end

contrasts = cell(1, n_bands);
for b = 1:n_bands
    contrasts{b} = v32_build_contrast(inverse, cfg.time_window_ms, band_limits(b,:));
end

mean_energy = zeros(n_vertices, n_bands);
mean_amplitude = zeros(n_vertices, n_bands);
for j = 1:n_trials
    raw = double(D(Ic{1}, It, good_trials(j)));
    for b = 1:n_bands
        Y = raw * contrasts{b}.TTW;
        Y = double(U{1}) * Y * double(scale);
        MYW = double(inverse.M) * Y;
        mean_amplitude(:,b) = mean_amplitude(:,b) + MYW(:,1);
        mean_energy(:,b) = mean_energy(:,b) + sum(MYW.^2, 2);
    end
end
mean_amplitude = mean_amplitude / n_trials;
mean_energy = mean_energy / n_trials;

posterior_variance = zeros(n_vertices, n_bands);
for b = 1:n_bands
    posterior_variance(:,b) = contrasts{b}.qC;
end
expected_energy = mean_energy + posterior_variance;
log_mean_energy = log(max(mean_energy, double(cfg.log_floor)));
percentile_log_mean_energy = zeros(size(mean_energy));
for b = 1:n_bands
    percentile_log_mean_energy(:,b) = local_percentile(log_mean_energy(:,b));
end

if cfg.store_as_single
    mean_amplitude = single(mean_amplitude);
    mean_energy = single(mean_energy);
    posterior_variance = single(posterior_variance);
    expected_energy = single(expected_energy);
    log_mean_energy = single(log_mean_energy);
    percentile_log_mean_energy = single(percentile_log_mean_energy);
end

result = struct();
result.pipeline_version = cfg.pipeline_version;
result.inverse_index = val;
result.band_names = band_names;
result.band_limits_hz = band_limits;
result.time_window_ms = contrasts{1}.woi_ms;
result.trial_label = string(trial_labels{1});
result.good_trial_indices = good_trials(:)';
result.n_good_trials = n_trials;
result.mean_amplitude = mean_amplitude;
result.mean_energy = mean_energy;
result.posterior_variance = posterior_variance;
result.expected_energy = expected_energy;
result.log_mean_energy = log_mean_energy;
result.percentile_log_mean_energy = percentile_log_mean_energy;
result.inverse_F = get_scalar(inverse, 'F');
result.inverse_R2 = get_scalar(inverse, 'R2');
result.inverse_VE = get_scalar(inverse, 'VE');
% L is normally sparse and very wide. Its rank equals the rank of the
% small sensor-space Gram matrix, which avoids densifying vertices x sensors.
sensor_gram = full(double(inverse.L * inverse.L'));
result.sensor_rank = rank(sensor_gram);
result.temporal_modes = size(inverse.T, 2);
result.sensor_modes = size(inverse.M, 2);
result.source_vertices = n_vertices;
result.model = model;
end

function p = local_percentile(x)
[sorted_x, order] = sort(x, 'ascend');
n = numel(x);
ranks = zeros(n,1);
i = 1;
while i <= n
    j = i;
    while j < n && sorted_x(j+1) == sorted_x(i)
        j = j + 1;
    end
    ranks(order(i:j)) = mean(i:j);
    i = j + 1;
end
p = (ranks - 0.5) / n;
end

function value = get_scalar(s, field_name)
if isfield(s, field_name) && isnumeric(s.(field_name)) && isscalar(s.(field_name))
    value = double(s.(field_name));
else
    value = NaN;
end
end
