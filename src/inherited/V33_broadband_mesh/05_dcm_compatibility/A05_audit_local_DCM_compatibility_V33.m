%% Quantify whether a 16-mm local DCM basis represents each broad support.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v33_setup();
out=fullfile(cfg.output_root,'05_dcm_compatibility');if ~exist(out,'dir'),mkdir(out);end
shortlist=readtable(fullfile(cfg.output_root,'04_discovery_models', ...
    'A04_broadband_DCM_shortlist_DISCOVERY_LOCKED.csv'),'Delimiter',',');
F=load(fullfile(cfg.project_root,'derivatives','V32_induced','07_resolution_supports', ...
    'A07_frozen_resolution_supports_LOCKED.mat'),'frozen');f=F.frozen;
vertices=double(f.vertices);faces=double(f.faces);support_id=double(f.support_id);supports=f.support_table;
edges=[faces(:,[1 2]);faces(:,[2 3]);faces(:,[3 1])];edges=unique(sort(edges,2),'rows');
w=sqrt(sum((vertices(edges(:,1),:)-vertices(edges(:,2),:)).^2,2));g=graph(edges(:,1),edges(:,2),w,size(vertices,1));
audit=table();centres=table();
for i=1:height(shortlist)
    s=shortlist.support_id(i);sr=supports(supports.support_id==s,:);members=find(support_id==s);
    seed=sr.representative_vertex;distance=distances(g,seed);patch=find(distance<=cfg.dcm_local_patch_radius_mm);
    intersection=intersect(members,patch);coverage=numel(intersection)/numel(members);purity=numel(intersection)/numel(patch);
    member_distance=distance(members);median_radius=median(member_distance,'omitnan');max_radius=max(member_distance,[],'omitnan');
    [seed_list,achieved]=greedy_cover(g,members,seed,cfg.dcm_local_patch_radius_mm, ...
        cfg.dcm_local_patch_target_coverage,cfg.dcm_local_patch_max_centres);
    compatible=coverage>=cfg.dcm_single_patch_min_support_coverage;
    row=table(shortlist.discovery_rank(i),s,numel(members),seed,coverage,purity, ...
        median_radius,max_radius,numel(seed_list),achieved,compatible, ...
        'VariableNames',{'discovery_rank','support_id','n_support_vertices', ...
        'representative_vertex','single_patch_support_coverage','single_patch_purity', ...
        'median_geodesic_radius_mm','max_geodesic_radius_mm','centres_for_target_coverage', ...
        'achieved_coverage','single_local_basis_compatible'});audit=[audit;row]; %#ok<AGROW>
    for j=1:numel(seed_list)
        v=seed_list(j);r=table(s,j,v,vertices(v,1),vertices(v,2),vertices(v,3), ...
            'VariableNames',{'support_id','centre_number','vertex','x','y','z'});centres=[centres;r]; %#ok<AGROW>
    end
end
writetable(audit,fullfile(out,'A05_local_DCM_basis_compatibility.csv'));
writetable(centres,fullfile(out,'A05_multicentre_coverage_coordinates.csv'));
save(fullfile(out,'A05_local_DCM_basis_compatibility.mat'),'audit','centres','cfg','-v7.3');
fprintf('Local-basis audit: %d/%d supports have >=%.0f%% coverage from one %.0f-mm patch.\n', ...
    sum(audit.single_local_basis_compatible),height(audit),100*cfg.dcm_single_patch_min_support_coverage,cfg.dcm_local_patch_radius_mm);
function [seeds,coverage]=greedy_cover(g,members,first,radius,target,max_centres)
seeds=first;covered=false(numel(members),1);minimum=inf(numel(members),1);
for k=1:max_centres
    d=distances(g,seeds(end));dm=d(members)';minimum=min(minimum,dm);covered=minimum<=radius;coverage=mean(covered);
    if coverage>=target||k==max_centres,return;end
    [~,idx]=max(minimum);seeds(end+1)=members(idx); %#ok<AGROW>
end
coverage=mean(covered);
end
