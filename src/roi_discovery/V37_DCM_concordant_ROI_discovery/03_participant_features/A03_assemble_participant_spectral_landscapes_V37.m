%% Assemble one DCM-concordant spatial spectral landscape per participant.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'lib'));
cfg = v37_setup();
out = fullfile(cfg.output_root, '03_participant_features');
if ~exist(out, 'dir'), mkdir(out); end

S = readtable(fullfile(cfg.output_root, '02_node_features', ...
    'A02_node_feature_extraction_status.csv'), 'Delimiter', ',');
for v = {'subject_id','group','condition','output_file','status'}
    S.(v{1}) = string(S.(v{1}));
end
S = S(ismember(S.status,["OK","SKIPPED_EXISTS"]),:);
if isempty(S), error('V37:Features', 'No successful V37 recording maps.'); end

split = readtable(fullfile(cfg.project_root, 'derivatives', 'V32_induced', ...
    '05_frozen_split', 'A05_participant_split_LOCKED.csv'), 'Delimiter', ',');
split.subject_id = string(split.subject_id);
split.group = string(split.group);
split.sex = string(split.sex);
split.age_band = string(split.age_band);
split.assignment = string(split.assignment);
split = split(split.assignment == "discovery", :);

example = load(char(S.output_file(1)), 'result');
npatch = numel(example.result.patch_id);
freq = double(example.result.spectral.frequency_hz(:)');
nf = numel(freq);
nsub = height(split);
EC = nan(nsub,npatch,nf,'single');
EO = nan(nsub,npatch,nf,'single');
reliability = nan(nsub,npatch,2,'single');
mode_rank = nan(nsub,npatch,2,'single');
filter_norm = nan(nsub,npatch,2,'single');
posterior_variance = nan(nsub,npatch,2,'single');
epoch_count = nan(nsub,2);

for r = 1:height(S)
    [ok, i] = ismember(S.subject_id(r), split.subject_id);
    if ~ok, error('V37:DiscoveryBoundary', 'Non-discovery subject entered V37.'); end
    loaded = load(char(S.output_file(r)), 'result');
    z = loaded.result;
    if S.condition(r) == "restEC"
        c = 1; EC(i,:,:) = z.spectral.log_spectrum;
    elseif S.condition(r) == "restEO"
        c = 2; EO(i,:,:) = z.spectral.log_spectrum;
    else
        error('V37:Condition', 'Unexpected condition %s.', S.condition(r));
    end
    reliability(i,:,c) = z.spectral.split_half_spectral_correlation;
    mode_rank(i,:,c) = z.regional_rank;
    filter_norm(i,:,c) = z.filter_norm;
    posterior_variance(i,:,c) = z.mean_posterior_variance;
    epoch_count(i,c) = z.spectral.n_good_epochs;
end

% Convert each condition into a within-participant spatial landscape. This
% removes the median across patches separately at every frequency.
EC_relative = local_spatial_relative(EC);
EO_relative = local_spatial_relative(EO);
average_relative_log_spectrum = local_nanmean4(EC_relative, EO_relative);
signed_EC_minus_EO_log_spectrum = EC_relative - EO_relative;
has_EC = squeeze(any(any(isfinite(EC),2),3));
has_EO = squeeze(any(any(isfinite(EO),2),3));
has_paired_conditions = has_EC & has_EO;

technical = struct();
technical.split_half_spectral_correlation = ...
    mean(reliability,3,'omitnan');
technical.regional_mode_rank = mean(mode_rank,3,'omitnan');
technical.filter_norm = mean(filter_norm,3,'omitnan');
technical.mean_posterior_variance = mean(posterior_variance,3,'omitnan');
technical.good_epoch_count = epoch_count;

available = has_EC | has_EO;
participants = split(available, {'subject_id','group','age','sex','age_band', ...
    'condition_availability','assignment'});
average_relative_log_spectrum = average_relative_log_spectrum(available,:,:);
signed_EC_minus_EO_log_spectrum = signed_EC_minus_EO_log_spectrum(available,:,:);
has_paired_conditions = has_paired_conditions(available);
fields = fieldnames(technical);
for i = 1:numel(fields)
    technical.(fields{i}) = technical.(fields{i})(available,:,:);
end

dataset = struct('participants', participants, 'frequency_hz', freq, ...
    'patch_id', (1:npatch)', ...
    'average_relative_log_spectrum', average_relative_log_spectrum, ...
    'signed_EC_minus_EO_log_spectrum', signed_EC_minus_EO_log_spectrum, ...
    'has_paired_conditions', has_paired_conditions, ...
    'technical', technical, ...
    'primary_representation', ...
    "condition-average log spectrum minus within-participant frequency-wise patch median", ...
    'n_validation_participants_read', 0);
save(fullfile(out, 'A03_participant_spectral_landscapes.mat'), ...
    'dataset', 'cfg', '-v7.3');

manifest = participants(:,{'subject_id','group','age','sex','age_band','condition_availability'});
manifest.has_paired_conditions = has_paired_conditions;
writetable(manifest, fullfile(out, 'A03_participant_feature_manifest.csv'));
fprintf('Assembled %d discovery participants (%d paired EC/EO); validation read = 0.\n', ...
    height(participants), sum(has_paired_conditions));

function X = local_spatial_relative(X)
for i = 1:size(X,1)
    for f = 1:size(X,3)
        v = double(X(i,:,f));
        if any(isfinite(v)), X(i,:,f) = v - median(v,'omitnan'); end
    end
end
end

function M = local_nanmean4(A,B)
M = A;
both = isfinite(A) & isfinite(B);
M(both) = (A(both) + B(both))/2;
only_b = ~isfinite(A) & isfinite(B);
M(only_b) = B(only_b);
end
