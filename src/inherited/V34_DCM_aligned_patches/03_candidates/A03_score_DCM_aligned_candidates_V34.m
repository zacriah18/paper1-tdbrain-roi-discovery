%% Score diagnosis-blind local-patch candidates and describe class separation separately.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v34_setup();
out=fullfile(cfg.output_root,'03_candidates');if ~exist(out,'dir'),mkdir(out);end
S=load(fullfile(cfg.output_root,'02_patch_metrics','A02_DCM_aligned_patch_metrics.mat'), ...
    'metrics','mean_psf','mean_ctf','patches');M=S.metrics;patches=S.patches;npatch=height(patches.patch_table);
for v={'subject_id','group','condition','assignment'},M.(v{1})=string(M.(v{1}));end
D=M(M.assignment=="discovery",:);

profiles=[S.mean_psf;S.mean_ctf];profiles=profiles./max(vecnorm(profiles),eps);
profile_similarity=profiles'*profiles;profile_similarity(1:npatch+1:end)=-Inf;
isolation=1-max(profile_similarity,[],2);isolation=max(0,min(1,isolation));

summary=table();
for p=1:npatch
    rows=D.patch_id==p;
    typical=median(D.mean_percentile_energy(rows),'omitnan');
    upper=prctile(D.mean_percentile_energy(rows),90);
    spatial_peak=median(D.spatial_peak_prominence(rows),'omitnan');
    fluctuation=median(D.epoch_log_mad(rows),'omitnan');
    burst=median(D.temporal_burst_prominence(rows),'omitnan');
    precision=median(D.posterior_precision(rows),'omitnan');
    modulation=paired_modulation(D,p);
    rel=zeros(2,1);conditions=["restEC","restEO"];
    for c=1:2
        q=rows&D.condition==conditions(c);r=corr(D.half1_log_energy(q),D.half2_log_energy(q),'Type','Spearman','Rows','complete');
        rel(c)=2*r/(1+r);
    end
    reliability=max(0,min(1,mean(rel,'omitnan')));
    row=table(p,typical,upper,spatial_peak,fluctuation,burst,modulation,precision,reliability,isolation(p), ...
        'VariableNames',{'patch_id','typical_energy','upper_tail_energy','spatial_peak_prominence', ...
        'epoch_fluctuation','temporal_burst_prominence','absolute_EC_EO_modulation', ...
        'posterior_precision','split_half_reliability','resolution_isolation'});summary=[summary;row]; %#ok<AGROW>
end

core={'typical_energy','upper_tail_energy','spatial_peak_prominence','epoch_fluctuation', ...
    'temporal_burst_prominence','absolute_EC_EO_modulation'};
for i=1:numel(core),summary.([core{i} '_percentile'])=tiedrank(summary.(core{i}))/height(summary);end
P=zeros(height(summary),numel(core));for i=1:numel(core),P(:,i)=summary.([core{i} '_percentile']);end
summary.core_upper_quartile_count=sum(P>=cfg.patch_core_percentile,2);
summary.mean_core_percentile=mean(P,2);
summary.precision_gate=summary.posterior_precision>=median(summary.posterior_precision,'omitnan');
summary.reliability_gate=summary.split_half_reliability>=cfg.patch_min_reliability;
summary.isolation_gate=summary.resolution_isolation>=median(summary.resolution_isolation,'omitnan');
summary.eligible=summary.core_upper_quartile_count>=cfg.patch_min_core_criteria & ...
    summary.precision_gate & summary.reliability_gate & summary.isolation_gate;
summary=outerjoin(summary,patches.patch_table,'Keys','patch_id','MergeKeys',true,'Type','left');

separation=class_description(D,patches.patch_table,cfg);
writetable(separation,fullfile(out,'A03_MDD_HC_class_description_NOT_SELECTION.csv'));
writetable(summary,fullfile(out,'A03_patch_investigatory_metrics_ALL.csv'));

ordered=sortrows(summary(summary.eligible,:),{'core_upper_quartile_count','mean_core_percentile','resolution_isolation'}, ...
    {'descend','descend','descend'});selected=false(height(ordered),1);centres=[];
coords=[ordered.x ordered.y ordered.z];
for i=1:height(ordered)
    p=ordered.patch_id(i);
    if ~isempty(centres)
        if any(profile_similarity(p,centres)>cfg.dcm_max_profile_cosine),continue;end
        old=[patches.patch_table.x(centres) patches.patch_table.y(centres) patches.patch_table.z(centres)];
        if any(sqrt(sum((old-coords(i,:)).^2,2))<cfg.patch_candidate_min_distance_mm),continue;end
    end
    selected(i)=true;centres(end+1)=p; %#ok<AGROW>
    if sum(selected)==cfg.patch_candidate_max,break;end
end
candidates=ordered(selected,:);candidates.candidate_rank=(1:height(candidates))';
[ok,loc]=ismember(candidates.patch_id,separation.patch_id);if ~all(ok),error('Separation join failed.');end
candidates.descriptive_cohen_d=separation.cohen_d_paired_average(loc);
candidates.descriptive_oof_AUC=separation.oof_AUC_feature_age_sex(loc);
candidates.descriptive_delta_AUC=separation.delta_AUC_over_age_sex(loc);
candidates.class_metrics_used_for_selection=repmat(false,height(candidates),1);
writetable(candidates,fullfile(out,'A03_DCM_aligned_possible_ROI_candidates.csv'));
save(fullfile(out,'A03_DCM_aligned_candidate_results.mat'),'summary','separation','candidates','profile_similarity','cfg','-v7.3');
fprintf('Candidate scoring: %d/%d eligible, %d retained after isolation/distance pruning.\n', ...
    sum(summary.eligible),height(summary),height(candidates));

function value=paired_modulation(D,p)
T=D(D.patch_id==p,:);ids=unique(T.subject_id);x=[];
for i=1:numel(ids),r=T(T.subject_id==ids(i),:);a=r.mean_percentile_energy(r.condition=="restEC");b=r.mean_percentile_energy(r.condition=="restEO");if numel(a)==1&&numel(b)==1,x(end+1)=abs(a-b);end,end %#ok<AGROW>
value=median(x,'omitnan');
end
function O=class_description(D,patch_table,cfg)
ids=unique(D.subject_id);paired=false(numel(ids),1);
for i=1:numel(ids),paired(i)=any(D.subject_id==ids(i)&D.condition=="restEC")&&any(D.subject_id==ids(i)&D.condition=="restEO");end
ids=ids(paired);n=numel(ids);np=height(patch_table);X=nan(n,np);Y=false(n,1);
split=readtable(fullfile(cfg.project_root,'derivatives','V32_induced','05_frozen_split','A05_participant_split_LOCKED.csv'),'Delimiter',',');split.subject_id=string(split.subject_id);
age=nan(n,1);sex=nan(n,1);
for i=1:n
    r=D(D.subject_id==ids(i),:);Y(i)=r.group(1)=="MDD";loc=find(split.subject_id==ids(i),1);age(i)=split.age(loc);sex(i)=double(string(split.sex(loc))=="1");
    for p=1:np,X(i,p)=mean(r.mean_percentile_energy(r.patch_id==p),'omitnan');end
end
rng(cfg.random_seed+34,'twister');cv=cvpartition(categorical(Y),'KFold',cfg.separation_folds);base_prediction=nan(n,1);
for f=1:cv.NumTestSets,tr=training(cv,f);te=test(cv,f);az=(age-mean(age(tr)))/std(age(tr));tb=table(Y,az,sex,'VariableNames',{'y','age','sex'});mdl=fitglm(tb(tr,:),'y~age+sex','Distribution','binomial');base_prediction(te)=predict(mdl,tb(te,:));end
[~,~,~,base_auc]=perfcurve(Y,base_prediction,true);O=table();
for p=1:np
    prediction=nan(n,1);
    for f=1:cv.NumTestSets
        tr=training(cv,f);te=test(cv,f);xz=(X(:,p)-mean(X(tr,p)))/std(X(tr,p));az=(age-mean(age(tr)))/std(age(tr));
        t=table(Y,xz,az,sex,'VariableNames',{'y','feature','age','sex'});mdl=fitglm(t(tr,:),'y~feature+age+sex','Distribution','binomial');prediction(te)=predict(mdl,t(te,:));
    end
    [~,~,~,auc]=perfcurve(Y,prediction,true);pred=prediction>=.5;sens=mean(pred(Y));spec=mean(~pred(~Y));bal=.5*(sens+spec);
    d_all=cohen(X(Y,p),X(~Y,p));d_ec=condition_d(D,p,"restEC");d_eo=condition_d(D,p,"restEO");d_int=interaction_d(D,p);
    row=table(p,n,d_all,d_ec,d_eo,d_int,auc,bal,base_auc,auc-base_auc, ...
        'VariableNames',{'patch_id','n_paired_discovery','cohen_d_paired_average','cohen_d_restEC','cohen_d_restEO','cohen_d_EC_EO_interaction','oof_AUC_feature_age_sex','oof_balanced_accuracy','oof_AUC_age_sex_only','delta_AUC_over_age_sex'});O=[O;row]; %#ok<AGROW>
end
end
function d=condition_d(D,p,c),r=D(D.patch_id==p&D.condition==c,:);d=cohen(r.mean_percentile_energy(r.group=="MDD"),r.mean_percentile_energy(r.group=="HC"));end
function d=interaction_d(D,p),T=D(D.patch_id==p,:);ids=unique(T.subject_id);m=[];h=[];for i=1:numel(ids),r=T(T.subject_id==ids(i),:);a=r.mean_percentile_energy(r.condition=="restEC");b=r.mean_percentile_energy(r.condition=="restEO");if numel(a)==1&&numel(b)==1,if r.group(1)=="MDD",m(end+1)=a-b;else,h(end+1)=a-b;end,end,end;d=cohen(m,h);end %#ok<AGROW>
function d=cohen(a,b),d=(mean(a)-mean(b))/(sqrt(((numel(a)-1)*var(a)+(numel(b)-1)*var(b))/max(numel(a)+numel(b)-2,1))+eps);end
