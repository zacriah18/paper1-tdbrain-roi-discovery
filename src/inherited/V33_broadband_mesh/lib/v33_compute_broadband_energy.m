function result=v33_compute_broadband_energy(D,cfg)
% Single-epoch posterior source energy across the full inverse temporal basis.
[model,inverse,val]=v32_get_inverse(D,cfg.inverse_index);
T=double(inverse.T); n_time=size(T,1);
orthogonality_error=norm(T'*T-eye(size(T,2)),'fro');
if orthogonality_error>cfg.temporal_orthogonality_tolerance
    error('V33:TemporalBasis','Temporal basis is not sufficiently orthonormal: %.3g',orthogonality_error);
end
try,trial_labels=inverse.trials;catch,trial_labels=D.condlist;end
if ischar(trial_labels)||isstring(trial_labels),trial_labels=cellstr(trial_labels);end
if numel(trial_labels)~=1,error('V33 expects one condition per file.');end
good_trials=D.indtrial(trial_labels{1},'GOOD');
if numel(good_trials)<cfg.minimum_good_epochs,error('Too few good epochs.');end
U=inverse.U;Ic=inverse.Ic;It=inverse.It;
if ~iscell(U),U={U};end;if ~iscell(Ic),Ic={Ic};end
try,scale=inverse.scale;catch,scale=1;end
if numel(scale)>1,scale=scale(1);end
M=double(inverse.M); energy=zeros(size(M,1),1);
for j=1:numel(good_trials)
    raw=double(D(Ic{1},It,good_trials(j)));
    coefficients=M*(double(U{1})*(raw*T)*double(scale));
    energy=energy+sum(coefficients.^2,2)/n_time;
end
energy=energy/numel(good_trials);
posterior_variance=full(double(inverse.qC)*trace(T'*double(inverse.qV)*T)/n_time);
posterior_variance=max(posterior_variance,0);
log_energy=log(max(energy,double(cfg.log_floor)));
percentile=percentile_rank(log_energy);
if cfg.store_as_single
    energy=single(energy);posterior_variance=single(posterior_variance);
    log_energy=single(log_energy);percentile=single(percentile);
end
result=struct('pipeline_version',cfg.pipeline_version,'inverse_index',val, ...
    'trial_label',string(trial_labels{1}),'good_trial_indices',good_trials(:)', ...
    'n_good_trials',numel(good_trials),'n_time_samples',n_time, ...
    'n_temporal_modes',size(T,2),'temporal_orthogonality_error',orthogonality_error, ...
    'mean_broadband_energy',energy,'posterior_variance',posterior_variance, ...
    'expected_broadband_energy',energy+posterior_variance, ...
    'log_broadband_energy',log_energy,'percentile_log_broadband_energy',percentile, ...
    'inverse_F',scalar(inverse,'F'),'inverse_R2',scalar(inverse,'R2'), ...
    'inverse_VE',scalar(inverse,'VE'),'source_vertices',size(M,1),'model',model);
end
function p=percentile_rank(x)
[sx,o]=sort(x);n=numel(x);r=zeros(n,1);i=1;
while i<=n,j=i;while j<n&&sx(j+1)==sx(i),j=j+1;end;r(o(i:j))=mean(i:j);i=j+1;end
p=(r-.5)/n;
end
function x=scalar(s,f)
if isfield(s,f)&&isnumeric(s.(f))&&isscalar(s.(f)),x=double(s.(f));else,x=NaN;end
end
