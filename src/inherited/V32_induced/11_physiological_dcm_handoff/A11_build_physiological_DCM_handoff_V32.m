%% Select diagnosis-blind, physiologically replicated DCM node supports.
clear; clc;
pipeline_root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root,'lib'));
cfg=v32_setup();
out_root=fullfile(cfg.output_root,'11_physiological_dcm_handoff');
if ~exist(out_root,'dir'),mkdir(out_root);end
handoff_csv=fullfile(out_root,'A11_DCM_node_handoff_LOCKED.csv');
if isfile(handoff_csv),error('V32:HandoffAlreadyBuilt','DCM handoff already exists.');end

F=load(fullfile(cfg.output_root,'07_resolution_supports', ...
    'A07_frozen_resolution_supports_LOCKED.mat'),'frozen');
frozen=F.frozen; support_id=double(frozen.support_id);
support_table=frozen.support_table; n_supports=height(support_table);

split=readtable(fullfile(cfg.output_root,'05_frozen_split', ...
    'A05_participant_split_LABEL_BLIND.csv'),'Delimiter',',');
split.subject_id=string(split.subject_id);split.assignment=string(split.assignment);
paired=readtable(fullfile(cfg.output_root,'03_subject_maps', ...
    'A03_paired_condition_status.csv'),'Delimiter',',');
paired.subject_id=string(paired.subject_id);paired.status=string(paired.status);
paired.paired_map_file=string(paired.paired_map_file);paired=paired(paired.status=="OK",:);
[ok,loc]=ismember(paired.subject_id,split.subject_id);
if ~all(ok),error('Missing split assignment for paired participants.');end
paired.assignment=split.assignment(loc);

n_bands=numel(cfg.band_names); n_rows=height(paired)*n_bands*n_supports;
subject_id=strings(n_rows,1);assignment=strings(n_rows,1);band=strings(n_rows,1);
support=zeros(n_rows,1);log_difference=nan(n_rows,1);percentile_difference=nan(n_rows,1);
cursor=0;
for i=1:height(paired)
    loaded=load(char(paired.paired_map_file(i)),'paired'); p=loaded.paired;
    for b=1:n_bands
        for s=1:n_supports
            cursor=cursor+1; vertices=support_id==s;
            subject_id(cursor)=paired.subject_id(i);assignment(cursor)=paired.assignment(i);
            band(cursor)=string(cfg.band_names{b});support(cursor)=s;
            log_difference(cursor)=mean(double(p.log_mean_energy_EC_minus_EO(vertices,b)),'omitnan');
            percentile_difference(cursor)=mean(double(p.percentile_EC_minus_EO(vertices,b)),'omitnan');
        end
    end
end
metrics=table(subject_id,assignment,band,support,log_difference,percentile_difference, ...
    'VariableNames',{'subject_id','assignment','band','support_id', ...
    'log_energy_EC_minus_EO','percentile_EC_minus_EO'});

R=readtable(fullfile(cfg.output_root,'09_reliability_candidates', ...
    'A09_split_half_reliability.csv'),'Delimiter',',');
R.band=string(R.band);
separability=compute_separability(frozen);
rng(cfg.random_seed+11,'twister');
discovery=table();
for b=1:n_bands
    for s=1:n_supports
        rows=metrics.assignment=="discovery" & metrics.band==string(cfg.band_names{b}) & metrics.support_id==s;
        x=metrics.log_energy_EC_minus_EO(rows); x=x(isfinite(x)); n=numel(x);
        mu=mean(x); sd=std(x); dz=mu/(sd+eps); direction=sign(mu); if direction==0,direction=1;end
        consistency=mean(sign(x)==direction);
        boot_means=mean(x(randi(n,n,cfg.physiology_bootstrap_samples)),1);
        stability=mean(sign(boot_means)==direction);
        boot_ci=prctile(boot_means,[2.5 97.5]);
        rr=R.band==string(cfg.band_names{b}) & R.support_id==s;
        reliability=max(0,min(1,mean(R.spearman_brown(rr),'omitnan')));
        row=table(string(cfg.band_names{b}),s,n,mu,sd,dz,consistency,stability, ...
            boot_ci(1),boot_ci(2),reliability,separability(s), ...
            'VariableNames',{'band','support_id','n_discovery','mean_log_difference', ...
            'sd_log_difference','cohen_dz','sign_consistency','bootstrap_sign_stability', ...
            'bootstrap_ci_lower','bootstrap_ci_upper','reliability','separability'});
        discovery=[discovery;row]; %#ok<AGROW>
    end
end

components={'effect_size','sign_consistency','bootstrap_sign_stability','reliability','separability'};
discovery.effect_size=abs(discovery.cohen_dz);
for i=1:numel(components)
    discovery.([components{i} '_percentile'])=tiedrank(discovery.(components{i}))/height(discovery);
end
w=cfg.physiology_score_weights;
discovery.physiology_score=w.effect_size*discovery.effect_size_percentile + ...
    w.sign_consistency*discovery.sign_consistency_percentile + ...
    w.bootstrap_stability*discovery.bootstrap_sign_stability_percentile + ...
    w.reliability*discovery.reliability_percentile + ...
    w.separability*discovery.separability_percentile;
ordered=sortrows(discovery,{'physiology_score','support_id'},{'descend','ascend'});
selected=false(height(ordered),1); used=[];
for i=1:height(ordered)
    if any(used==ordered.support_id(i)),continue;end
    selected(i)=true;used(end+1)=ordered.support_id(i); %#ok<SAGROW>
    if sum(selected)==cfg.physiology_discovery_shortlist,break;end
end
shortlist=ordered(selected,:);shortlist.discovery_rank=(1:height(shortlist))';

validation=table();
for i=1:height(shortlist)
    rows=metrics.assignment=="validation" & metrics.band==shortlist.band(i) & ...
        metrics.support_id==shortlist.support_id(i);
    x=metrics.log_energy_EC_minus_EO(rows);x=x(isfinite(x));
    [~,p,ci,stats]=ttest(x,0); dz=mean(x)/(std(x)+eps);
    row=table(shortlist.discovery_rank(i),shortlist.band(i),shortlist.support_id(i), ...
        numel(x),mean(x),std(x),dz,stats.tstat,stats.df,p,ci(1),ci(2), ...
        sign(mean(x))==sign(shortlist.mean_log_difference(i)), ...
        'VariableNames',{'discovery_rank','band','support_id','n_validation', ...
        'mean_log_difference','sd_log_difference','cohen_dz','t_statistic','df', ...
        'p_value','ci_lower','ci_upper','direction_matches_discovery'});
    validation=[validation;row]; %#ok<AGROW>
end
validation.p_holm=holm_adjust(validation.p_value);
validation.replicated=validation.direction_matches_discovery & validation.p_holm<=0.05;

profiles=support_profiles(frozen); similarity=profiles'*profiles;
coords=[support_table.representative_x support_table.representative_y support_table.representative_z];
node_rows=[]; selected_supports=[];
for i=1:height(shortlist)
    v=validation(validation.discovery_rank==shortlist.discovery_rank(i),:);
    if ~v.replicated,continue;end
    s=shortlist.support_id(i);
    if ~isempty(selected_supports)
        if any(similarity(s,selected_supports)>cfg.dcm_max_profile_cosine),continue;end
        distance=sqrt(sum((coords(selected_supports,:)-coords(s,:)).^2,2));
        if any(distance<cfg.dcm_min_coordinate_distance_mm),continue;end
    end
    node_rows(end+1)=i;selected_supports(end+1)=s; %#ok<AGROW>
    if numel(node_rows)==cfg.dcm_max_nodes,break;end
end
if numel(node_rows)<cfg.dcm_min_nodes
    error('V32:InsufficientDCMNodes', ...
        'Only %d nodes survived frozen replication and redundancy gates.',numel(node_rows));
end

nodes=shortlist(node_rows,:);
nodes.node_id=(1:height(nodes))';
[~,sloc]=ismember(nodes.support_id,support_table.support_id);
nodes.hemisphere=support_table.hemisphere(sloc);
nodes.n_vertices=support_table.n_vertices(sloc);
nodes.representative_x=support_table.representative_x(sloc);
nodes.representative_y=support_table.representative_y(sloc);
nodes.representative_z=support_table.representative_z(sloc);
nodes.atlas_overlap=support_table.atlas_overlap(sloc);
[~,vloc]=ismember(nodes.discovery_rank,validation.discovery_rank);
nodes.validation_cohen_dz=validation.cohen_dz(vloc);
nodes.validation_p_holm=validation.p_holm(vloc);
nodes.validation_ci_lower=validation.ci_lower(vloc);
nodes.validation_ci_upper=validation.ci_upper(vloc);

writetable(metrics,fullfile(out_root,'A11_paired_support_metrics.csv'));
writetable(discovery,fullfile(out_root,'A11_discovery_physiology_scores_ALL.csv'));
writetable(shortlist,fullfile(out_root,'A11_discovery_shortlist_LOCKED.csv'));
writetable(validation,fullfile(out_root,'A11_validation_replication.csv'));
writetable(nodes,handoff_csv);
save(fullfile(out_root,'A11_physiological_DCM_handoff_LOCKED.mat'), ...
    'nodes','shortlist','validation','discovery','metrics','similarity','cfg','-v7.3');
fprintf('DCM handoff frozen: %d nodes; %d/%d shortlist effects replicated.\n', ...
    height(nodes),sum(validation.replicated),height(validation));

function sep=compute_separability(frozen)
P=support_profiles(frozen);S=P'*P;S(1:size(S,1)+1:end)=-Inf;sep=1-max(S,[],2);sep=max(0,min(1,sep));
end
function P=support_profiles(frozen)
initial=frozen.initial_component_id;final=frozen.support_id;n_initial=size(frozen.mean_psf,1);n_supports=max(final);
membership=zeros(n_initial,1);for i=1:n_initial,membership(i)=mode(final(initial==i));end
P=zeros(2*n_initial,n_supports);
for s=1:n_supports,m=find(membership==s);w=frozen.initial_components.n_vertices(m);w=w/sum(w);P(:,s)=[frozen.mean_psf(:,m)*w;frozen.mean_ctf(:,m)*w];end
P=P./max(vecnorm(P),eps);
end
function adjusted=holm_adjust(p)
[sorted,order]=sort(p);m=numel(p);raw=(m-(1:m)'+1).*sorted;monotone=min(cummax(raw),1);adjusted=zeros(size(p));adjusted(order)=monotone;
end
