%% Prespecified EC/EO and selected-patch QC sensitivity analyses.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'06_heldout_validation');
V=load(fullfile(out,'A11_frozen_validation_results.mat'),'discovery','dataset');
discovery=V.discovery;dataset=V.dataset;P=dataset.participants;n=height(P);
S=readtable(fullfile(out,'A09_validation_extraction_status.csv'),'Delimiter',',');
for v={'subject_id','condition','output_file','status'},S.(v{1})=string(S.(v{1}));end
S=S(ismember(S.status,["OK","SKIPPED_EXISTS"]),:);
npatch=numel(dataset.patch_id);nf=numel(dataset.frequency_hz);
EC=nan(n,npatch,nf,'single');EO=nan(n,npatch,nf,'single');
for r=1:height(S)
    [ok,i]=ismember(S.subject_id(r),string(P.subject_id));if ~ok,error('V371:SensitivityJoin','Subject join failed.');end
    L=load(char(S.output_file(r)),'result');spectrum=L.result.spectral.log_spectrum;
    if S.condition(r)=="restEC",EC(i,:,:)=spectrum;else,EO(i,:,:)=spectrum;end
end
EC=local_relative(EC);EO=local_relative(EO);[Z,~]=v371_nuisance_matrix(P);y=double(string(P.group)=="MDD");
conditions={"restEC",EC;"restEO",EO};rows=table();
for c=1:size(conditions,1)
    label=conditions{c,1};array=conditions{c,2};available=squeeze(any(any(isfinite(array),2),3));
    coeff=local_coeff(array(available,:,:),discovery.spectral_basis);
    primary=local_apply(discovery.final_patch_ids,discovery.frozen_model,coeff,Z(available,:));
    secondary=local_apply(discovery.dcm_candidate_patch_ids,discovery.dcm_frozen_model,coeff,Z(available,:));
    demo=local_demo(discovery,Z(available,:));yy=y(available);PP=P(available,:);
    candidates={"primary_K1",primary;"secondary_DCM_K4",secondary};
    for m=1:size(candidates,1)
        name=candidates{m,1};prob=candidates{m,2};metric=v371_metrics(yy,prob);dm=v371_metrics(yy,demo);
        delta=dm.log_loss-metric.log_loss;p=local_conditional_p(yy,PP,demo,prob, ...
            cfg.validation_fixed_permutation_count,cfg.validation_fixed_permutation_seed+400000+100000*c+10000*m);
        rows=[rows;table(label,name,sum(available),metric.AUC,metric.log_loss,delta,metric.Brier, ...
            metric.balanced_accuracy,metric.calibration_intercept,metric.calibration_slope,p, ...
            'VariableNames',{'condition','model','n_participants','AUC','log_loss','incremental_log_loss', ...
            'Brier','balanced_accuracy','calibration_intercept','calibration_slope','conditional_p_value'})]; %#ok<AGROW>
    end
end
writetable(rows,fullfile(out,'A13_EC_EO_frozen_model_sensitivity.csv'));

patch=discovery.final_patch_ids(1);q=cfg.spectral_basis_count;
average_coeff=local_coeff(dataset.average_relative_log_spectrum,discovery.spectral_basis);
X=squeeze(average_coeff(:,patch,:));cols=1:q;model=discovery.frozen_model;
Xs=(X-model.neural_mean(cols))./model.neural_scale(cols);neural_score=Xs*model.model.beta(cols);
T=dataset.technical;qc=[double(T.split_half_spectral_correlation(:,patch)), ...
    double(T.regional_mode_rank(:,patch)),log(max(double(T.filter_norm(:,patch)),realmin)), ...
    double(T.mean_posterior_variance(:,patch)),mean(double(T.good_epoch_count),2,'omitnan')];
qc_names=["split_half_reliability","regional_mode_rank","log_filter_norm","posterior_variance","mean_good_epoch_count"];
qc_rows=table();pvals=zeros(numel(qc_names),1);
for j=1:numel(qc_names)
    v=qc(:,j);observed=mean(v(y==1),'omitnan')-mean(v(y==0),'omitnan');
    pvals(j)=local_group_p(v,y,P,cfg.validation_fixed_permutation_count, ...
        cfg.validation_fixed_permutation_seed+600000+10000*j);
    rho=corr(v,neural_score,'Type','Spearman','Rows','complete');
    qc_rows=[qc_rows;table(patch,qc_names(j),observed,pvals(j),rho, ...
        'VariableNames',{'patch_id','QC_metric','mean_MDD_minus_HC','conditional_p_value','Spearman_with_frozen_neural_score'})]; %#ok<AGROW>
end
qc_rows.p_Holm=local_holm(pvals);qc_rows.reject_Holm_0_05=qc_rows.p_Holm<=0.05;
writetable(qc_rows,fullfile(out,'A13_primary_patch_QC_sensitivity.csv'));
save(fullfile(out,'A13_condition_and_QC_sensitivity.mat'),'rows','qc_rows','cfg','-v7.3');
fprintf('CONDITION/QC SENSITIVITY COMPLETE: EC and EO scored; %d/%d QC metrics Holm-positive.\n',sum(qc_rows.reject_Holm_0_05),height(qc_rows));

function relative=local_relative(X)
relative=X;for i=1:size(X,1),for f=1:size(X,3),v=double(X(i,:,f));if any(isfinite(v)),relative(i,:,f)=v-median(v,'omitnan');end,end,end
end
function coeff=local_coeff(S,B)
n=size(S,1);npatch=size(S,2);coeff=reshape(reshape(double(S),n*npatch,[])*B,n,npatch,size(B,2));
end
function p=local_apply(ids,model,coeff,Z)
X=reshape(permute(coeff(:,ids,:),[1 3 2]),size(coeff,1),[]);Xs=(X-model.neural_mean)./model.neural_scale;Xs(~isfinite(Xs))=0;
Zs=(Z-model.nuisance_mean)./model.nuisance_scale;Zs(~isfinite(Zs))=0;p=local_sigmoid(Xs*model.model.beta+Zs*model.model.gamma+model.model.intercept);
end
function p=local_demo(discovery,Z)
m=discovery.frozen_model;Zs=(Z-m.nuisance_mean)./m.nuisance_scale;Zs(~isfinite(Zs))=0;p=local_sigmoid([ones(size(Z,1),1),Zs]*discovery.frozen_demographic_model.beta);
end
function pvalue=local_conditional_p(y,P,p0,p1,B,seed)
[~,~,sex]=v371_nuisance_matrix(P);key=string(P.age_band)+"|sex="+string(sex)+"|condition="+string(P.condition_availability);[names,~,id]=unique(key,'stable');
observed=mean(local_loss(y,p0)-local_loss(y,p1));null=zeros(B,1);
for b=1:B,yp=local_permute(y,id,numel(names),seed+b-1);null(b)=mean(local_loss(yp,p0)-local_loss(yp,p1));end
pvalue=(1+sum(null>=observed))/(B+1);
end
function pvalue=local_group_p(v,y,P,B,seed)
[~,~,sex]=v371_nuisance_matrix(P);key=string(P.age_band)+"|sex="+string(sex)+"|condition="+string(P.condition_availability);[names,~,id]=unique(key,'stable');
observed=abs(mean(v(y==1),'omitnan')-mean(v(y==0),'omitnan'));null=zeros(B,1);
for b=1:B,yp=local_permute(y,id,numel(names),seed+b-1);null(b)=abs(mean(v(yp==1),'omitnan')-mean(v(yp==0),'omitnan'));end
pvalue=(1+sum(null>=observed))/(B+1);
end
function yp=local_permute(y,id,nblock,seed)
stream=RandStream('mt19937ar','Seed',seed);yp=y;for k=1:nblock,idx=find(id==k);if numel(idx)>1,yp(idx)=y(idx(randperm(stream,numel(idx))));end,end
end
function adjusted=local_holm(p)
[sorted,order]=sort(p);m=numel(p);raw=(m-(1:m)'+1).*sorted;monotone=min(cummax(raw),1);adjusted=zeros(size(p));adjusted(order)=monotone;
end
function loss=local_loss(y,p),p=min(max(p(:),1e-8),1-1e-8);loss=-(y(:).*log(p)+(1-y(:)).*log(1-p));end
function p=local_sigmoid(x),p=1./(1+exp(-max(min(x,35),-35)));end
