%% Audit whether the 12 local nodes are distinguishable by the saved operators.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v35_setup();
out=fullfile(cfg.output_root,'01_identifiability');if ~exist(out,'dir'),mkdir(out);end
P=load(fullfile(cfg.project_root,'derivatives','V34_DCM_aligned_patches', ...
    '01_patch_tiling','A01_DCM_aligned_16mm_patches.mat'),'patches');patches=P.patches;
C=load(fullfile(cfg.project_root,'derivatives','V34_DCM_aligned_patches', ...
    '03_candidates','A03_DCM_aligned_candidate_results.mat'),'candidates');candidates=sortrows(C.candidates,'candidate_rank');
patch_ids=candidates.patch_id;nnode=numel(patch_ids);status=v35_discovery_recordings(cfg);

membership=patches.membership(:,patch_ids)>0;overlap=zeros(nnode);jaccard=zeros(nnode);
coords=[candidates.x candidates.y candidates.z];distance=squareform(pdist(coords));
for i=1:nnode,for j=i+1:nnode
    inter=sum(membership(:,i)&membership(:,j));overlap(i,j)=inter;overlap(j,i)=inter;
    uni=sum(membership(:,i)|membership(:,j));jaccard(i,j)=inter/max(uni,1);jaccard(j,i)=jaccard(i,j);
end,end

sum_profile=zeros(nnode);sum_profile2=zeros(nnode);sum_lead=zeros(nnode);sum_lead2=zeros(nnode);
sum_submax=zeros(nnode);sum_submax2=zeros(nnode);sum_subrms=zeros(nnode);sum_subrms2=zeros(nnode);nprofile=0;
rec_subject=strings(height(status),1);rec_condition=strings(height(status),1);rec_group=strings(height(status),1);
observable_rank=zeros(height(status),1);observable_effective_rank=zeros(height(status),1);observable_condition=nan(height(status),1);
sixmode_rank=zeros(height(status),1);sixmode_effective_rank=zeros(height(status),1);
for r=1:height(status)
    D=spm_eeg_load(char(status.source_file(r)));node=v35_node_operator(D,cfg,patches,patch_ids);
    R=abs(node.resolution);R=R./max(vecnorm(R),eps);profile=R'*R;
    G=node.leadfield;G=G./max(vecnorm(G),eps);lead=abs(G'*G);
    submax=eye(nnode);subrms=eye(nnode);
    for i=1:nnode,for j=i+1:nnode
        canonical=svd(node.local_basis{i}'*node.local_basis{j});
        submax(i,j)=max(canonical);submax(j,i)=submax(i,j);
        subrms(i,j)=sqrt(mean(canonical.^2));subrms(j,i)=subrms(i,j);
    end,end
    sum_profile=sum_profile+profile;sum_profile2=sum_profile2+profile.^2;
    sum_lead=sum_lead+lead;sum_lead2=sum_lead2+lead.^2;
    sum_submax=sum_submax+submax;sum_submax2=sum_submax2+submax.^2;
    sum_subrms=sum_subrms+subrms;sum_subrms2=sum_subrms2+subrms.^2;nprofile=nprofile+1;
    sv=svd(G);observable_rank(r)=sum(sv>max(sv)*1e-6);observable_effective_rank(r)=effective_rank(sv);
    observable_condition(r)=sv(1)/max(sv(observable_rank(r)),eps);
    Q=[];for i=1:nnode,Q=[Q node.local_basis{i}];end %#ok<AGROW>
    svq=svd(Q);sixmode_rank(r)=sum(svq>max(svq)*1e-6);sixmode_effective_rank(r)=effective_rank(svq);
    rec_subject(r)=status.subject_id(r);rec_condition(r)=status.condition(r);rec_group(r)=status.group(r);
    fprintf('%d/%d %s %s rank=%d\n',r,height(status),status.subject_id(r),status.condition(r),observable_rank(r));
end

[profile,profile_sd]=finish(sum_profile,sum_profile2,nprofile);[lead,lead_sd]=finish(sum_lead,sum_lead2,nprofile);
[submax,submax_sd]=finish(sum_submax,sum_submax2,nprofile);[subrms,subrms_sd]=finish(sum_subrms,sum_subrms2,nprofile);
records=table(rec_subject,rec_group,rec_condition,observable_rank,observable_effective_rank,observable_condition, ...
    sixmode_rank,sixmode_effective_rank,'VariableNames',{'subject_id','group','condition','observable_node_rank', ...
    'observable_node_effective_rank','observable_node_condition_number','six_mode_union_rank','six_mode_union_effective_rank'});
writetable(records,fullfile(out,'A01_recording_level_identifiability.csv'));

pair=table();
for i=1:nnode,for j=i+1:nnode
    row=table(i,j,patch_ids(i),patch_ids(j),distance(i,j),overlap(i,j),jaccard(i,j), ...
        profile(i,j),profile_sd(i,j),lead(i,j),lead_sd(i,j),submax(i,j),submax_sd(i,j),subrms(i,j),subrms_sd(i,j), ...
        profile(i,j)>=cfg.identifiability_profile_warning|subrms(i,j)>=cfg.identifiability_subspace_warning, ...
        'VariableNames',{'rank_i','rank_j','patch_i','patch_j','centre_distance_mm','overlap_vertices','vertex_jaccard', ...
        'resolution_profile_cosine_mean','resolution_profile_cosine_sd','observable_leadfield_cosine_mean','observable_leadfield_cosine_sd', ...
        'regional_subspace_max_canonical_mean','regional_subspace_max_canonical_sd','regional_subspace_rms_canonical_mean', ...
        'regional_subspace_rms_canonical_sd','confusability_warning'});pair=[pair;row]; %#ok<AGROW>
end,end
writetable(pair,fullfile(out,'A01_pairwise_patch_identifiability.csv'));
nodes=candidates(:,{'candidate_rank','patch_id','hemisphere','x','y','z','n_vertices','atlas_overlap'});
writetable(nodes,fullfile(out,'A01_node_manifest.csv'));
save(fullfile(out,'A01_patch_identifiability_results.mat'),'pair','records','nodes','profile','lead','submax','subrms','cfg','-v7.3');

fid=fopen(fullfile(out,'A01_IDENTIFIABILITY_DECISION.md'),'w');
fprintf(fid,'# V35 12-node identifiability decision\n\n');
fprintf(fid,'Discovery recordings audited: %d. Nodes: %d.\n\n',height(status),nnode);
fprintf(fid,'- Median observable-node rank: %.1f/%d.\n',median(observable_rank),nnode);
fprintf(fid,'- Median observable-node effective rank: %.2f/%d.\n',median(observable_effective_rank),nnode);
fprintf(fid,'- Median observable-node condition number: %.2f.\n',median(observable_condition,'omitnan'));
fprintf(fid,'- Pair warnings (resolution cosine >= %.2f or regional-subspace RMS canonical correlation >= %.2f): %d/%d.\n', ...
    cfg.identifiability_profile_warning,cfg.identifiability_subspace_warning,sum(pair.confusability_warning),height(pair));
fprintf(fid,'- Pairs with shared vertices: %d/%d.\n\n',sum(pair.overlap_vertices>0),height(pair));
fprintf(fid,'Warnings identify node pairs that should not be assigned independent causal interpretations without a DCM-specific identifiability check.\n');fclose(fid);

function r=effective_rank(s),p=(s.^2)/sum(s.^2);r=exp(-sum(p.*log(max(p,eps))));end
function [m,sd]=finish(s,s2,n),m=s/n;sd=sqrt(max(0,s2/n-m.^2));end
