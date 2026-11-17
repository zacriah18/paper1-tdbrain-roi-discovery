%% Build support metrics and discovery-only broadband group mesh contrasts.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v33_setup();
out=fullfile(cfg.output_root,'03_grouping');if ~exist(out,'dir'),mkdir(out);end
F=load(fullfile(cfg.project_root,'derivatives','V32_induced','07_resolution_supports', ...
    'A07_frozen_resolution_supports_LOCKED.mat'),'frozen');frozen=F.frozen;
support_id=double(frozen.support_id);n_supports=max(support_id);vertices=frozen.vertices;
status=readtable(fullfile(cfg.output_root,'02_recording_maps','A02_extraction_status.csv'),'Delimiter',',');
for v={'subject_id','group','condition','output_file','status'},status.(v{1})=string(status.(v{1}));end
status=status(ismember(status.status,["OK","SKIPPED_EXISTS"]),:);
split=readtable(fullfile(cfg.project_root,'derivatives','V32_induced','05_frozen_split', ...
    'A05_participant_split_LOCKED.csv'),'Delimiter',',');
split.subject_id=string(split.subject_id);split.group=string(split.group);split.assignment=string(split.assignment);

nrows=height(status)*n_supports;sid=strings(nrows,1);grp=strings(nrows,1);cond=strings(nrows,1);
assignment=strings(nrows,1);support=zeros(nrows,1);n_vertices=zeros(nrows,1);
mean_percentile=nan(nrows,1);mean_log=nan(nrows,1);mean_energy=nan(nrows,1);precision=nan(nrows,1);
n_good=zeros(nrows,1);inverse_VE=nan(nrows,1);cursor=0;
cell_names=["HC_restEC","HC_restEO","MDD_restEC","MDD_restEO"];
sum_map=zeros(numel(support_id),4);sumsq_map=zeros(numel(support_id),4);cell_n=zeros(4,1);
for i=1:height(status)
    loaded=load(char(status.output_file(i)),'result');r=loaded.result;
    loc=find(split.subject_id==status.subject_id(i),1);if isempty(loc),error('Missing split.');end
    for s=1:n_supports
        cursor=cursor+1;vv=support_id==s;e=double(r.mean_broadband_energy(vv));pv=double(r.posterior_variance(vv));
        sid(cursor)=status.subject_id(i);grp(cursor)=status.group(i);cond(cursor)=status.condition(i);
        assignment(cursor)=split.assignment(loc);support(cursor)=s;n_vertices(cursor)=sum(vv);
        mean_percentile(cursor)=mean(double(r.percentile_log_broadband_energy(vv)),'omitnan');
        mean_log(cursor)=mean(double(r.log_broadband_energy(vv)),'omitnan');mean_energy(cursor)=mean(e,'omitnan');
        precision(cursor)=mean(e./(e+pv+eps),'omitnan');n_good(cursor)=r.n_good_trials;inverse_VE(cursor)=r.inverse_VE;
    end
    if split.assignment(loc)=="discovery"
        key=status.group(i)+"_"+status.condition(i);c=find(cell_names==key,1);
        x=double(r.percentile_log_broadband_energy);sum_map(:,c)=sum_map(:,c)+x;
        sumsq_map(:,c)=sumsq_map(:,c)+x.^2;cell_n(c)=cell_n(c)+1;
    end
end
support_metrics=table(sid,grp,cond,assignment,support,n_vertices,mean_percentile,mean_log, ...
    mean_energy,precision,n_good,inverse_VE,'VariableNames',{'subject_id','group','condition', ...
    'assignment','support_id','n_vertices','mean_percentile_log_broadband_energy', ...
    'mean_log_broadband_energy','mean_broadband_energy','posterior_precision', ...
    'n_good_trials','inverse_VE'});
writetable(support_metrics,fullfile(out,'A03_broadband_support_metrics.csv'));

means=sum_map./cell_n';vars=(sumsq_map-(sum_map.^2)./cell_n')./max(cell_n'-1,1);sds=sqrt(max(vars,0));
d_ec=cohen_d(means(:,3),means(:,1),sds(:,3),sds(:,1),cell_n(3),cell_n(1));
d_eo=cohen_d(means(:,4),means(:,2),sds(:,4),sds(:,2),cell_n(4),cell_n(2));

paired_ids=split.subject_id(split.assignment=="discovery");
diff_sum=zeros(numel(support_id),2);diff_sumsq=zeros(numel(support_id),2);diff_n=zeros(2,1);
for i=1:numel(paired_ids)
    rows=status(status.subject_id==paired_ids(i),:);ec=rows(rows.condition=="restEC",:);eo=rows(rows.condition=="restEO",:);
    if height(ec)~=1||height(eo)~=1,continue;end
    A=load(char(ec.output_file),'result');B=load(char(eo.output_file),'result');x=double(A.result.percentile_log_broadband_energy)-double(B.result.percentile_log_broadband_energy);
    g=1+(string(A.result.group)=="MDD");diff_sum(:,g)=diff_sum(:,g)+x;diff_sumsq(:,g)=diff_sumsq(:,g)+x.^2;diff_n(g)=diff_n(g)+1;
end
dm=diff_sum./diff_n';dv=(diff_sumsq-(diff_sum.^2)./diff_n')./max(diff_n'-1,1);ds=sqrt(max(dv,0));
d_interaction=cohen_d(dm(:,2),dm(:,1),ds(:,2),ds(:,1),diff_n(2),diff_n(1));
group_maps=struct('cell_names',cell_names,'cell_n',cell_n,'mean_percentile_maps',means, ...
    'cohen_d_MDD_minus_HC_restEC',d_ec,'cohen_d_MDD_minus_HC_restEO',d_eo, ...
    'paired_n_HC_MDD',diff_n,'cohen_d_interaction_ECminusEO',d_interaction, ...
    'vertices',vertices,'support_id',support_id);
save(fullfile(out,'A03_discovery_broadband_group_mesh_maps.mat'),'group_maps','cfg','-v7.3');

contrasts={d_ec,d_eo,d_interaction};names=["MDD_minus_HC_restEC","MDD_minus_HC_restEO","MDDminusHC_by_ECminusEO"];
top=table();
for c=1:3
    [~,order]=sort(abs(contrasts{c}),'descend');order=order(1:100);
    t=table(repmat(names(c),100,1),order,vertices(order,1),vertices(order,2),vertices(order,3), ...
        support_id(order),contrasts{c}(order),'VariableNames',{'contrast','vertex','x','y','z','support_id','cohen_d'});
    top=[top;t]; %#ok<AGROW>
end
writetable(top,fullfile(out,'A03_discovery_top_broadband_vertices_DESCRIPTIVE.csv'));
fprintf('Broadband grouping complete: %d support rows; discovery cells [%s].\n',height(support_metrics),num2str(cell_n'));
function d=cohen_d(m1,m0,s1,s0,n1,n0)
pooled=sqrt(((n1-1).*s1.^2+(n0-1).*s0.^2)./max(n1+n0-2,1));d=(m1-m0)./(pooled+eps);
end
