%% Build a provisional six-node handoff without using class/connectivity metrics.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v35_setup();
out=fullfile(cfg.output_root,'04_dcm_handoff');if ~exist(out,'dir'),mkdir(out);end
C=load(fullfile(cfg.project_root,'derivatives','V34_DCM_aligned_patches', ...
    '03_candidates','A03_DCM_aligned_candidate_results.mat'),'candidates');candidates=sortrows(C.candidates,'candidate_rank');
I=readtable(fullfile(cfg.output_root,'01_identifiability','A01_pairwise_patch_identifiability.csv'),'Delimiter',',');
n=height(candidates);warning=false(n);for r=1:height(I),warning(I.rank_i(r),I.rank_j(r))=I.confusability_warning(r);warning(I.rank_j(r),I.rank_i(r))=I.confusability_warning(r);end

best=[];best_score=[];target=min(cfg.dcm_max_nodes,n);
while isempty(best)&&target>=cfg.dcm_min_nodes
    sets=nchoosek(1:n,target);
    for r=1:size(sets,1)
        q=sets(r,:);if any(any(triu(warning(q,q),1))),continue;end
        score=[sum(candidates.candidate_rank(q)), -sum(candidates.core_upper_quartile_count(q)), ...
            -sum(candidates.mean_core_percentile(q)), -sum(candidates.resolution_isolation(q))];
        if isempty(best_score)||lexless(score,best_score),best=q;best_score=score;end
    end
    if isempty(best),target=target-1;end
end
if isempty(best),error('V35:DCMHandoff','No non-confusable set meeting the frozen minimum node count.');end
handoff=candidates(best,:);handoff.dcm_node_number=(1:height(handoff))';handoff.selection_uses_class_metrics=false(height(handoff),1);
handoff.selection_uses_connectivity_metrics=false(height(handoff),1);handoff.selection_status=repmat("PROVISIONAL_IDENTIFIABLE_HANDOFF",height(handoff),1);
writetable(handoff,fullfile(out,'A04_provisional_identifiable_DCM_nodes.csv'));

excluded=candidates(~ismember((1:n)',best),:);conflicts=strings(height(excluded),1);
for r=1:height(excluded)
    ix=find(candidates.patch_id==excluded.patch_id(r));q=best(warning(ix,best));
    if isempty(q),conflicts(r)="lower diagnosis-blind V34 rank than selected feasible set";else,conflicts(r)="confusable with selected candidate rank(s): "+join(string(q),",");end
end
excluded.exclusion_reason=conflicts;writetable(excluded,fullfile(out,'A04_nonselected_candidate_audit.csv'));

fid=fopen(fullfile(out,'A04_DCM_HANDOFF_DECISION.md'),'w');
fprintf(fid,'# V35 provisional DCM handoff\n\n');
fprintf(fid,'A %d-node set was selected from the 12 V34 candidates by exhaustive search. Feasible sets contain no V35 pairwise confusability warning. Among feasible sets, the decision minimizes the summed diagnosis-blind V34 candidate ranks, then uses the frozen V34 investigatory metrics as tie-breakers. MDD/HC and connectivity metrics are excluded.\n\n',height(handoff));
fprintf(fid,'| DCM node | V34 rank | Patch | Coordinate (mm) | Hemisphere | Atlas overlap |\n|---:|---:|---:|---|---|---|\n');
for r=1:height(handoff)
    fprintf(fid,'| %d | %d | %d | %.1f, %.1f, %.1f | %s | %s |\n',handoff.dcm_node_number(r),handoff.candidate_rank(r),handoff.patch_id(r),handoff.x(r),handoff.y(r),handoff.z(r),string(handoff.hemisphere(r)),string(handoff.atlas_overlap(r)));
end
fprintf(fid,'\n## Status and next model step\n\n');
fprintf(fid,'This is a provisional, operator-identifiable coordinate set, not a causal network and not an MDD biomarker. Fit a small anatomically constrained cross-spectral DCM model space to sensor cross-spectra. Compare connection families and condition effects at first level; use PEB for group, age, and sex effects; apply model reduction/averaging; then test frozen effects in the untouched validation participants. Do not seed DCM edges from the V35 class-separation maxima.\n');fclose(fid);
save(fullfile(out,'A04_provisional_DCM_handoff.mat'),'handoff','excluded','warning','cfg','-v7.3');

function tf=lexless(a,b)
tf=false;for i=1:numel(a),if a(i)<b(i),tf=true;return;elseif a(i)>b(i),return;end,end
end
