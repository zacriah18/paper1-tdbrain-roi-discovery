%% Run discovery-only broadband group models and freeze an exploratory shortlist.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v33_setup();
out=fullfile(cfg.output_root,'04_discovery_models');if ~exist(out,'dir'),mkdir(out);end
result_file=fullfile(out,'A04_broadband_discovery_group_terms.csv');if isfile(result_file),error('Discovery models already run.');end
M=readtable(fullfile(cfg.output_root,'03_grouping','A03_broadband_support_metrics.csv'),'Delimiter',',');
for v={'subject_id','group','condition','assignment'},M.(v{1})=string(M.(v{1}));end;M=M(M.assignment=="discovery",:);
split=readtable(fullfile(cfg.project_root,'derivatives','V32_induced','05_frozen_split','A05_participant_split_LOCKED.csv'),'Delimiter',',');
split.subject_id=string(split.subject_id);split.sex=string(split.sex);
F=load(fullfile(cfg.project_root,'derivatives','V32_induced','07_resolution_supports','A07_frozen_resolution_supports_LOCKED.mat'),'frozen');frozen=F.frozen;supports=frozen.support_table;
results=table();audit=table();
for s=1:height(supports)
    data=M(M.support_id==s,:);[ok,loc]=ismember(data.subject_id,split.subject_id);if ~all(ok),error('Missing metadata.');end
    data.age=split.age(loc);data.sex=split.sex(loc);data.subject_id=categorical(data.subject_id);
    data.group=reordercats(categorical(data.group),{'HC','MDD'});data.condition=reordercats(categorical(data.condition),{'restEC','restEO'});data.sex=categorical(data.sex);
    formula=['mean_percentile_log_broadband_energy ~ group*condition + age + sex + ' ...
        'n_good_trials + inverse_VE + (1|subject_id)'];lme=fitlme(data,formula,'FitMethod','REML');C=lme.Coefficients;names=string(C.Name);
    idx=[find(contains(names,"group_MDD")&~contains(names,":"),1) find(contains(names,"group_MDD")&contains(names,"condition_restEO"),1)];
    labels=["diagnosis_MDD","diagnosis_by_restEO"];
    for j=1:2,k=idx(j);r=table(s,labels(j),C.Estimate(k),C.SE(k),C.DF(k),C.tStat(k),C.pValue(k),C.Lower(k),C.Upper(k), ...
        'VariableNames',{'support_id','term','estimate','standard_error','df','t_statistic','p_value','ci_lower','ci_upper'});results=[results;r];end %#ok<AGROW>
    a=table(s,height(data),lme.ModelCriterion.AIC,lme.ModelCriterion.BIC,'VariableNames',{'support_id','n_recordings','AIC','BIC'});audit=[audit;a]; %#ok<AGROW>
end
results.p_holm=holm(results.p_value);results.reject_holm_0_05=results.p_holm<=.05;
writetable(results,result_file);writetable(audit,fullfile(out,'A04_model_audit.csv'));

score=table();
for s=1:height(supports)
    rr=results(results.support_id==s,:);[mx,k]=max(abs(rr.t_statistic));
    row=table(s,mx,rr.term(k),rr.estimate(k),rr.p_value(k),rr.p_holm(k),supports.n_vertices(s), ...
        'VariableNames',{'support_id','max_abs_group_t','driving_term','driving_estimate','driving_p','driving_p_holm','n_vertices'});score=[score;row]; %#ok<AGROW>
end
score=sortrows(score,{'max_abs_group_t','support_id'},{'descend','ascend'});
similarity=support_similarity(frozen);coords=[supports.representative_x supports.representative_y supports.representative_z];selected=[];selected_supports=[];
for i=1:height(score)
    s=score.support_id(i);if score.n_vertices(i)<cfg.candidate_min_support_vertices,continue;end
    if ~isempty(selected_supports)
        if any(similarity(s,selected_supports)>cfg.dcm_max_profile_cosine),continue;end
        if any(sqrt(sum((coords(selected_supports,:)-coords(s,:)).^2,2))<cfg.dcm_min_coordinate_distance_mm),continue;end
    end
    selected(end+1)=i;selected_supports(end+1)=s; %#ok<AGROW>
    if numel(selected)==cfg.group_shortlist_max_supports,break;end
end
shortlist=score(selected,:);[~,loc]=ismember(shortlist.support_id,supports.support_id);
shortlist.hemisphere=supports.hemisphere(loc);shortlist.representative_x=supports.representative_x(loc);shortlist.representative_y=supports.representative_y(loc);shortlist.representative_z=supports.representative_z(loc);shortlist.atlas_overlap=supports.atlas_overlap(loc);
shortlist.discovery_rank=(1:height(shortlist))';shortlist.allowed_for_validation_DCM_PEB=repmat(true,height(shortlist),1);
writetable(score,fullfile(out,'A04_broadband_support_group_ranking.csv'));writetable(shortlist,fullfile(out,'A04_broadband_DCM_shortlist_DISCOVERY_LOCKED.csv'));
save(fullfile(out,'A04_broadband_discovery_results.mat'),'results','score','shortlist','similarity','cfg','-v7.3');
fprintf('Discovery models: %d/40 Holm-significant terms; %d broadband DCM supports frozen.\n',sum(results.reject_holm_0_05),height(shortlist));
function a=holm(p),[sp,o]=sort(p);m=numel(p);z=min(cummax((m-(1:m)'+1).*sp),1);a=zeros(size(p));a(o)=z;end
function S=support_similarity(f)
initial=f.initial_component_id;final=f.support_id;ni=size(f.mean_psf,1);ns=max(final);mem=zeros(ni,1);for i=1:ni,mem(i)=mode(final(initial==i));end
P=zeros(2*ni,ns);for s=1:ns,m=find(mem==s);w=f.initial_components.n_vertices(m);w=w/sum(w);P(:,s)=[f.mean_psf(:,m)*w;f.mean_ctf(:,m)*w];end;P=P./max(vecnorm(P),eps);S=P'*P;
end
