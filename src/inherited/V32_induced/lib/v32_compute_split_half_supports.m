function out = v32_compute_split_half_supports(D, cfg, support_id)
% Compute deterministic alternating-epoch half maps and support summaries.

[~, inverse] = v32_get_inverse(D, cfg.inverse_index);
band_names = cfg.band_names;
band_limits = cfg.band_limits_hz;
if cfg.include_secondary_bands
    band_names = [band_names cfg.secondary_band_names];
    band_limits = [band_limits; cfg.secondary_band_limits_hz];
end
n_bands = numel(band_names);
n_vertices = size(inverse.M,1);
n_supports = max(support_id);

try, trial_labels = inverse.trials; catch, trial_labels = D.condlist; end
if ischar(trial_labels) || isstring(trial_labels), trial_labels=cellstr(trial_labels); end
if numel(trial_labels)~=1, error('Expected one condition.'); end
good_trials = D.indtrial(trial_labels{1},'GOOD');
halves = {good_trials(1:2:end),good_trials(2:2:end)};
if min(cellfun(@numel,halves)) < cfg.reliability_min_epochs_per_half
    error('V32:TooFewSplitEpochs','Insufficient epochs in one split half.');
end

U=inverse.U; Ic=inverse.Ic; It=inverse.It;
if ~iscell(U),U={U};end
if ~iscell(Ic),Ic={Ic};end
try, scale=inverse.scale; catch, scale=1; end
if numel(scale)>1,scale=scale(1);end
contrasts=cell(1,n_bands);
for b=1:n_bands
    contrasts{b}=v32_build_contrast(inverse,cfg.time_window_ms,band_limits(b,:));
end

support_percentile=nan(n_supports,n_bands,2);
support_log_energy=nan(n_supports,n_bands,2);
for h=1:2
    energy=zeros(n_vertices,n_bands);
    for j=1:numel(halves{h})
        raw=double(D(Ic{1},It,halves{h}(j)));
        for b=1:n_bands
            Y=double(U{1})*(raw*contrasts{b}.TTW)*double(scale);
            MYW=double(inverse.M)*Y;
            energy(:,b)=energy(:,b)+sum(MYW.^2,2);
        end
    end
    energy=energy/numel(halves{h});
    log_energy=log(max(energy,double(cfg.log_floor)));
    percentile=zeros(size(log_energy));
    for b=1:n_bands, percentile(:,b)=percentile_rank(log_energy(:,b)); end
    for s=1:n_supports
        vertices=support_id==s;
        support_percentile(s,:,h)=mean(percentile(vertices,:),1,'omitnan');
        support_log_energy(s,:,h)=mean(log_energy(vertices,:),1,'omitnan');
    end
end

out=struct('band_names',{band_names},'band_limits_hz',band_limits, ...
    'good_trial_indices',good_trials(:)','half1_trials',halves{1}(:)', ...
    'half2_trials',halves{2}(:)','support_percentile',support_percentile, ...
    'support_log_energy',support_log_energy);
end

function p=percentile_rank(x)
[sorted_x,order]=sort(x,'ascend'); n=numel(x); ranks=zeros(n,1); i=1;
while i<=n
    j=i; while j<n && sorted_x(j+1)==sorted_x(i),j=j+1;end
    ranks(order(i:j))=mean(i:j); i=j+1;
end
p=(ranks-0.5)/n;
end
