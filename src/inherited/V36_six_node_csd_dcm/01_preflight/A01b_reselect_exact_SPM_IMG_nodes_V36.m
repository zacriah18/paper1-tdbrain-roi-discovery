%% Re-audit all 12 V34 candidates using SPM's exact Euclidean IMG basis.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v36_setup();
out=fullfile(cfg.output_root,'01_preflight');if ~exist(out,'dir'),mkdir(out);end
all=readtable(fullfile(cfg.project_root,'derivatives','V34_DCM_aligned_patches','03_candidates', ...
    'A03_DCM_aligned_possible_ROI_candidates.csv'),'Delimiter',',');all=sortrows(all,'candidate_rank');n=height(all);
recordings=v36_discovery_recordings(cfg);seed_file=fullfile(out,'A01b_exact_12_node_template_not_inverted.mat');
DCM=v36_build_dcm_spec(cfg,recordings(1,:),seed_file);DCM.Sname=cellstr("candidate_"+string(all.candidate_rank));
DCM.Lpos=[all.x';all.y';all.z'];DCM=spm_dcm_erp_data(DCM);DCM=spm_dcm_erp_dipfit(DCM,1);
Q=cell(n,1);node=table();
for i=1:n
    G=full(DCM.M.dipfit.G{i});Q{i}=orth(G);sv=svd(G);
    row=table(all.candidate_rank(i),all.patch_id(i),size(G,2),rank(G),effective_rank(sv), ...
        'VariableNames',{'candidate_rank','patch_id','regional_modes','regional_mode_rank','regional_effective_rank'});node=[node;row]; %#ok<AGROW>
end
old=readtable(fullfile(cfg.project_root,'derivatives','V35_patch_network_audit','01_identifiability', ...
    'A01_pairwise_patch_identifiability.csv'),'Delimiter',',');old_warning=false(n);
for r=1:height(old),old_warning(old.rank_i(r),old.rank_j(r))=old.confusability_warning(r);old_warning(old.rank_j(r),old.rank_i(r))=old.confusability_warning(r);end
exact_warning=false(n);pair=table();
for i=1:n,for j=i+1:n
    s=svd(Q{i}'*Q{j});rms=sqrt(mean(s.^2));exact_warning(i,j)=rms>=cfg.exact_subspace_warning;exact_warning(j,i)=exact_warning(i,j);
    row=table(i,j,all.patch_id(i),all.patch_id(j),max(s),rms,exact_warning(i,j),old_warning(i,j),exact_warning(i,j)|old_warning(i,j), ...
        'VariableNames',{'rank_i','rank_j','patch_i','patch_j','maximum_canonical_correlation','rms_canonical_correlation', ...
        'exact_SPM_IMG_warning','V35_inverse_warning','combined_warning'});pair=[pair;row]; %#ok<AGROW>
end,end
target=6;sets=nchoosek(1:n,target);best=[];score_best=[];
for r=1:size(sets,1)
    q=sets(r,:);if ~ismember(cfg.focal_v34_rank,q),continue;end
    exact_penalty=sum(sum(triu(exact_warning(q,q),1)));old_penalty=sum(sum(triu(old_warning(q,q),1)));
    score=[exact_penalty,old_penalty,sum(all.candidate_rank(q)),-sum(all.core_upper_quartile_count(q)),-sum(all.mean_core_percentile(q))];
    if isempty(best)||lexless(score,score_best),best=q;score_best=score;end
end
if isempty(best),error('V36:ExactSelection','No six-node set includes focal rank %d.',cfg.focal_v34_rank);end
handoff=all(best,:);handoff.dcm_node_number=(1:height(handoff))';handoff.dcm_name=short_name(handoff.candidate_rank);
handoff.exact_SPM_IMG_selection=true(height(handoff),1);handoff.selection_uses_class_metrics=false(height(handoff),1);
handoff.selection_uses_connectivity_metrics=false(height(handoff),1);
handoff.exact_SPM_IMG_warning_pairs_in_selected_set=repmat(score_best(1),height(handoff),1);
handoff.prior_V35_warning_pairs_in_selected_set=repmat(score_best(2),height(handoff),1);
writetable(node,fullfile(out,'A01b_exact_SPM_IMG_all_node_modes.csv'));writetable(pair,fullfile(out,'A01b_exact_SPM_IMG_all_pairwise_audit.csv'));
writetable(handoff,fullfile(out,'A01b_exact_SPM_IMG_six_node_handoff.csv'));save(seed_file,'DCM','node','pair','handoff','exact_warning','old_warning','cfg','-v7.3');
disp(handoff(:,{'dcm_node_number','candidate_rank','patch_id','dcm_name','x','y','z'}));
function r=effective_rank(s),p=(s.^2)/sum(s.^2);r=exp(-sum(p.*log(max(p,eps))));end
function tf=lexless(a,b),tf=false;for i=1:numel(a),if a(i)<b(i),tf=true;return;elseif a(i)>b(i),return;end,end,end
function name=short_name(rank)
labels=["R_mSFG_ACC","L_mSFG","L_orbitofrontal","L_orbIFG_aIns","R_MFG_IFG","L_ITG_MTG", ...
    "R_AnG_SPL_MOG","L_AnG_MOG","L_ITG_FuG","R_ITG_MTG","R_postcentral","L_MFG"];
name=labels(rank)';
end
