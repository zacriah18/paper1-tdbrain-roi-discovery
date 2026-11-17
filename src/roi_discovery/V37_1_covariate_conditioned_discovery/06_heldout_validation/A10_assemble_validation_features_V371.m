%% Assemble validation participant features using the frozen 452-patch normalization.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'06_heldout_validation');
S=readtable(fullfile(out,'A09_validation_extraction_status.csv'),'Delimiter',',');
for v={'subject_id','group','condition','output_file','status'},S.(v{1})=string(S.(v{1}));end
S=S(ismember(S.status,["OK","SKIPPED_EXISTS"]),:);
split=readtable(fullfile(cfg.project_root,'derivatives','V32_induced','05_frozen_split', ...
    'A05_participant_split_LOCKED.csv'),'Delimiter',',');
split.subject_id=string(split.subject_id);split.group=string(split.group);split.sex=string(split.sex);
split.age_band=string(split.age_band);split.assignment=string(split.assignment);
split=split(split.assignment=="validation",:);
if height(split)~=cfg.expected_validation_participants,error('V371:ValidationCount','Expected 98 validation rows.');end
example=load(char(S.output_file(1)),'result');npatch=numel(example.result.patch_id);
freq=double(example.result.spectral.frequency_hz(:)');nf=numel(freq);nsub=height(split);
EC=nan(nsub,npatch,nf,'single');EO=nan(nsub,npatch,nf,'single');
reliability=nan(nsub,npatch,2,'single');mode_rank=nan(nsub,npatch,2,'single');
filter_norm=nan(nsub,npatch,2,'single');posterior_variance=nan(nsub,npatch,2,'single');epoch_count=nan(nsub,2);
for r=1:height(S)
    [ok,i]=ismember(S.subject_id(r),split.subject_id);if ~ok,error('V371:ValidationBoundary','Non-validation recording entered assembly.');end
    loaded=load(char(S.output_file(r)),'result');z=loaded.result;
    if S.condition(r)=="restEC"
        c=1;EC(i,:,:)=z.spectral.log_spectrum;
    elseif S.condition(r)=="restEO"
        c=2;EO(i,:,:)=z.spectral.log_spectrum;
    else
        error('V371:Condition','Unexpected condition.');
    end
    reliability(i,:,c)=z.spectral.split_half_spectral_correlation;mode_rank(i,:,c)=z.regional_rank;
    filter_norm(i,:,c)=z.filter_norm;posterior_variance(i,:,c)=z.mean_posterior_variance;
    epoch_count(i,c)=z.spectral.n_good_epochs;
end
EC_relative=local_spatial_relative(EC);EO_relative=local_spatial_relative(EO);
average_relative_log_spectrum=local_nanmean4(EC_relative,EO_relative);
has_EC=squeeze(any(any(isfinite(EC),2),3));has_EO=squeeze(any(any(isfinite(EO),2),3));available=has_EC|has_EO;
if sum(available)~=cfg.expected_validation_participants,error('V371:ValidationCompleteness','Not all validation participants have a usable recording.');end
technical=struct('split_half_spectral_correlation',mean(reliability,3,'omitnan'), ...
    'regional_mode_rank',mean(mode_rank,3,'omitnan'),'filter_norm',mean(filter_norm,3,'omitnan'), ...
    'mean_posterior_variance',mean(posterior_variance,3,'omitnan'),'good_epoch_count',epoch_count);
participants=split(:,{'subject_id','group','age','sex','age_band','condition_availability','assignment'});
dataset=struct('participants',participants,'frequency_hz',freq,'patch_id',(1:npatch)', ...
    'average_relative_log_spectrum',average_relative_log_spectrum, ...
    'has_paired_conditions',has_EC&has_EO,'technical',technical, ...
    'primary_representation',"condition-average log spectrum minus within-participant frequency-wise patch median", ...
    'n_validation_participants_read',height(participants),'prior_V32_validation_use',true);
save(fullfile(out,'A10_validation_participant_spectral_landscapes.mat'),'dataset','cfg','-v7.3');
writetable(participants,fullfile(out,'A10_validation_participant_manifest.csv'));
fprintf('ASSEMBLED VALIDATION FEATURES: %d participants; cohort is now consumed for V37.1 confirmation.\n',height(participants));
function X=local_spatial_relative(X)
for i=1:size(X,1),for f=1:size(X,3),v=double(X(i,:,f));if any(isfinite(v)),X(i,:,f)=v-median(v,'omitnan');end,end,end
end
function M=local_nanmean4(A,B)
M=A;both=isfinite(A)&isfinite(B);M(both)=(A(both)+B(both))/2;only_b=~isfinite(A)&isfinite(B);M(only_b)=B(only_b);
end
