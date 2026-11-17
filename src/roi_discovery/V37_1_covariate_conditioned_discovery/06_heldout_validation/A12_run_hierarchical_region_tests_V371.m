%% Secondary regional tests after successful frozen global confirmation.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'06_heldout_validation');
V=load(fullfile(out,'A11_frozen_validation_results.mat'),'validation','discovery','dataset');
validation=V.validation;discovery=V.discovery;dataset=V.dataset;
if validation.primary_conditional_p_value>0.05
    error('V371:RegionHierarchy','Primary global confirmation did not pass; regional tests remain closed.');
end
ids=discovery.dcm_candidate_patch_ids(:);y=double(string(dataset.participants.group)=="MDD");
[Z,~]=v371_nuisance_matrix(dataset.participants);model=discovery.dcm_frozen_model;
Zs=(Z-model.nuisance_mean)./model.nuisance_scale;Zs(~isfinite(Zs))=0;
Bbasis=discovery.spectral_basis;n=height(dataset.participants);npatch=numel(dataset.patch_id);
S=double(dataset.average_relative_log_spectrum);coeff=reshape(reshape(S,n*npatch,[])*Bbasis,n,npatch,cfg.spectral_basis_count);
[block_name,block_id]=local_blocks(dataset.participants);B=cfg.validation_fixed_permutation_count;
rows=table();
for i=1:numel(ids)
    X=squeeze(coeff(:,ids(i),:));cols=(i-1)*cfg.spectral_basis_count+(1:cfg.spectral_basis_count);
    Xs=(X-model.neural_mean(cols))./model.neural_scale(cols);Xs(~isfinite(Xs))=0;
    nuisance=[ones(n,1),Zs];residual=Xs-nuisance*(nuisance\Xs);
    observed_omnibus=local_hotelling(residual,y);
    frozen_score=Xs*model.model.beta(cols);observed_direction=mean(frozen_score(y==1))-mean(frozen_score(y==0));
    null_omnibus=zeros(B,1);null_direction=zeros(B,1);
    for b=1:B
        yp=local_permute(y,block_id,numel(block_name),cfg.validation_fixed_permutation_seed+300000+10000*i+b-1);
        null_omnibus(b)=local_hotelling(residual,yp);
        null_direction(b)=mean(frozen_score(yp==1))-mean(frozen_score(yp==0));
    end
    p_omnibus=(1+sum(null_omnibus>=observed_omnibus))/(B+1);
    p_direction=(1+sum(null_direction>=observed_direction))/(B+1);
    rows=[rows;table(ids(i),observed_omnibus,p_omnibus,observed_direction,p_direction,B, ...
        'VariableNames',{'patch_id','six_component_Hotelling_T2','p_omnibus_two_sided', ...
        'frozen_direction_mean_MDD_minus_HC','p_frozen_direction_one_sided','permutations'})]; %#ok<AGROW>
end
rows.p_omnibus_Holm=local_holm(rows.p_omnibus_two_sided);
rows.omnibus_reject_Holm_0_05=rows.p_omnibus_Holm<=0.05;
rows.p_frozen_direction_Holm=local_holm(rows.p_frozen_direction_one_sided);
rows.direction_reject_Holm_0_05=rows.p_frozen_direction_Holm<=0.05;
writetable(rows,fullfile(out,'A12_hierarchical_region_tests.csv'));
save(fullfile(out,'A12_hierarchical_region_tests.mat'),'rows','ids','cfg','-v7.3');
fprintf('HIERARCHICAL REGION TESTS COMPLETE: %d/%d omnibus Holm confirmations.\n',sum(rows.omnibus_reject_Holm_0_05),height(rows));
function statistic=local_hotelling(X,y)
X0=X(y==0,:);X1=X(y==1,:);n0=size(X0,1);n1=size(X1,1);d=mean(X1,1)-mean(X0,1);
S=((n0-1)*cov(X0)+(n1-1)*cov(X1))/max(n0+n1-2,1);ridge=1e-6*trace(S)/max(size(S,1),1)+1e-9;
statistic=(n0*n1/(n0+n1))*(d/(S+eye(size(S))*ridge))*d';
end
function [names,id]=local_blocks(P)
[~,~,sex]=v371_nuisance_matrix(P);key=string(P.age_band)+"|sex="+string(sex)+"|condition="+string(P.condition_availability);
[names,~,id]=unique(key,'stable');
end
function yp=local_permute(y,block_id,nblock,seed)
stream=RandStream('mt19937ar','Seed',seed);yp=y;
for k=1:nblock,idx=find(block_id==k);if numel(idx)>1,yp(idx)=y(idx(randperm(stream,numel(idx))));end,end
end
function adjusted=local_holm(p)
[sorted,order]=sort(p);m=numel(p);raw=(m-(1:m)'+1).*sorted;monotone=min(cummax(raw),1);adjusted=zeros(size(p));adjusted(order)=monotone;
end
