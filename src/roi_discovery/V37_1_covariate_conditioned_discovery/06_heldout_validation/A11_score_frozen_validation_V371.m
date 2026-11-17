%% Score the frozen primary and secondary models once in the 98 participants.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'06_heldout_validation');
result_file=fullfile(out,'A11_frozen_validation_results.mat');
if exist(result_file,'file'),error('V371:ValidationAlreadyScored','Frozen validation results already exist.');end
R=load(fullfile(cfg.output_root,'05_peer_set_comparison','A08_peer_set_comparison.mat'),'result');discovery=R.result;
V=load(fullfile(out,'A10_validation_participant_spectral_landscapes.mat'),'dataset');dataset=V.dataset;
if height(dataset.participants)~=cfg.expected_validation_participants||any(string(dataset.participants.assignment)~="validation")
    error('V371:ValidationCount','Expected exactly 98 validation participants.');
end
y=double(string(dataset.participants.group)=="MDD");[Z,~]=v371_nuisance_matrix(dataset.participants);
B=discovery.spectral_basis;n=height(dataset.participants);npatch=numel(dataset.patch_id);
S=double(dataset.average_relative_log_spectrum);coeff=reshape(reshape(S,n*npatch,[])*B,n,npatch,cfg.spectral_basis_count);

primary=local_apply(discovery.final_patch_ids,discovery.frozen_model,coeff,Z);
Zs=(Z-discovery.frozen_model.nuisance_mean)./discovery.frozen_model.nuisance_scale;Zs(~isfinite(Zs))=0;
demographic=local_sigmoid([ones(n,1),Zs]*discovery.frozen_demographic_model.beta);
primary_metrics=v371_metrics(y,primary);demographic_metrics=v371_metrics(y,demographic);
observed_delta=demographic_metrics.log_loss-primary_metrics.log_loss;
[p_primary,null_primary,permutation_audit]=local_conditional_test(y,dataset.participants,demographic,primary, ...
    cfg.validation_fixed_permutation_count,cfg.validation_fixed_permutation_seed);
[ci_low,ci_high]=local_bootstrap_ci(local_loss(y,demographic)-local_loss(y,primary),y,5000,cfg.validation_fixed_permutation_seed+1);

secondary_metrics=[];secondary_delta=NaN;p_secondary=NaN;secondary_probability=[];null_secondary=[];
if ~isempty(discovery.dcm_candidate_patch_ids)
    secondary_probability=local_apply(discovery.dcm_candidate_patch_ids,discovery.dcm_frozen_model,coeff,Z);
    secondary_metrics=v371_metrics(y,secondary_probability);secondary_delta=demographic_metrics.log_loss-secondary_metrics.log_loss;
    [p_secondary,null_secondary]=local_conditional_test(y,dataset.participants,demographic,secondary_probability, ...
        cfg.validation_fixed_permutation_count,cfg.validation_fixed_permutation_seed+100000);
end

summary=table("demographic",numel(y),demographic_metrics.AUC,demographic_metrics.log_loss, ...
    demographic_metrics.Brier,demographic_metrics.balanced_accuracy,demographic_metrics.sensitivity, ...
    demographic_metrics.specificity,demographic_metrics.calibration_intercept,demographic_metrics.calibration_slope, ...
    NaN,NaN,NaN,NaN,'VariableNames',{'model','n_participants','AUC','log_loss','Brier', ...
    'balanced_accuracy','sensitivity','specificity','calibration_intercept','calibration_slope', ...
    'incremental_log_loss','incremental_log_loss_CI_low','incremental_log_loss_CI_high','conditional_p_value'});
summary=[summary;table("primary_K"+numel(discovery.final_patch_ids),numel(y),primary_metrics.AUC,primary_metrics.log_loss, ...
    primary_metrics.Brier,primary_metrics.balanced_accuracy,primary_metrics.sensitivity,primary_metrics.specificity, ...
    primary_metrics.calibration_intercept,primary_metrics.calibration_slope,observed_delta,ci_low,ci_high,p_primary, ...
    'VariableNames',summary.Properties.VariableNames)];
if ~isempty(secondary_metrics)
    summary=[summary;table("secondary_DCM_K"+numel(discovery.dcm_candidate_patch_ids),numel(y), ...
        secondary_metrics.AUC,secondary_metrics.log_loss,secondary_metrics.Brier,secondary_metrics.balanced_accuracy, ...
        secondary_metrics.sensitivity,secondary_metrics.specificity,secondary_metrics.calibration_intercept, ...
        secondary_metrics.calibration_slope,secondary_delta,NaN,NaN,p_secondary, ...
        'VariableNames',summary.Properties.VariableNames)];
end
writetable(summary,fullfile(out,'A11_frozen_validation_performance.csv'));
prediction=dataset.participants(:,{'subject_id','group','age','sex','age_band','condition_availability'});
prediction.demographic_probability=demographic;prediction.primary_probability=primary;
if ~isempty(secondary_probability),prediction.secondary_DCM_probability=secondary_probability;end
writetable(prediction,fullfile(out,'A11_frozen_validation_predictions.csv'));
claim_tier="internal held-out V37.1 confirmation; cohort previously used in V32; not external untouched validation";
validation=struct('summary',summary,'prediction',prediction,'observed_primary_delta_log_loss',observed_delta, ...
    'primary_conditional_p_value',p_primary,'primary_null_delta_log_loss',null_primary, ...
    'secondary_conditional_p_value',p_secondary,'secondary_null_delta_log_loss',null_secondary, ...
    'permutation_audit',permutation_audit,'claim_tier',claim_tier,'validation_participants_read',height(dataset.participants));
save(result_file,'validation','discovery','dataset','cfg','-v7.3');
fprintf('FROZEN VALIDATION SCORED: primary deltaLL=%.4f p=%.6f; validation read=%d.\n',observed_delta,p_primary,height(dataset.participants));

function p=local_apply(ids,model,coeff,Z)
X=reshape(permute(coeff(:,ids,:),[1 3 2]),size(coeff,1),[]);
Xs=(X-model.neural_mean)./model.neural_scale;Xs(~isfinite(Xs))=0;
Zs=(Z-model.nuisance_mean)./model.nuisance_scale;Zs(~isfinite(Zs))=0;
p=local_sigmoid(Xs*model.model.beta+Zs*model.model.gamma+model.model.intercept);
end
function [pvalue,null,audit]=local_conditional_test(y,P,p0,p1,B,seed)
[~,~,sex_binary]=v371_nuisance_matrix(P);key=string(P.age_band)+"|sex="+string(sex_binary)+"|condition="+string(P.condition_availability);
[block_name,~,block_id]=unique(key,'stable');observed=mean(local_loss(y,p0)-local_loss(y,p1));null=zeros(B,1);
block_size=accumarray(block_id,1);block_mdd=accumarray(block_id,y);mixed=block_mdd>0&block_mdd<block_size;
for b=1:B
    stream=RandStream('mt19937ar','Seed',seed+b-1);yp=y;
    for k=1:numel(block_name),idx=find(block_id==k);if numel(idx)>1,yp(idx)=y(idx(randperm(stream,numel(idx))));end,end
    null(b)=mean(local_loss(yp,p0)-local_loss(yp,p1));
end
pvalue=(1+sum(null>=observed))/(B+1);audit=struct('blocks',block_name,'block_id',block_id, ...
    'block_size',block_size,'block_MDD_count',block_mdd,'mixed_label_blocks',sum(mixed), ...
    'participants_in_mixed_blocks',sum(block_size(mixed)),'permutations',B,'seed',seed);
end
function [lo,hi]=local_bootstrap_ci(values,y,B,seed)
rng(seed,'twister');boot=zeros(B,1);a=find(y==0);b=find(y==1);
for i=1:B,idx=[a(randi(numel(a),numel(a),1));b(randi(numel(b),numel(b),1))];boot(i)=mean(values(idx));end
v=prctile(boot,[2.5 97.5]);lo=v(1);hi=v(2);
end
function loss=local_loss(y,p),p=min(max(p(:),1e-8),1-1e-8);loss=-(y(:).*log(p)+(1-y(:)).*log(1-p));end
function p=local_sigmoid(x),p=1./(1+exp(-max(min(x,35),-35)));end
