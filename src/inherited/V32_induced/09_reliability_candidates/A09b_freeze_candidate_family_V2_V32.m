%% Freeze revised nonredundant candidate family; validation remains unopened.
clear; clc;
pipeline_root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root,'lib'));
cfg=v32_setup();
out_root=fullfile(cfg.output_root,'09_reliability_candidates');
locked_mat=fullfile(out_root,'A09b_candidate_family_V2_LOCKED.mat');
if isfile(locked_mat)
    error('V32:CandidateV2AlreadyFrozen','V2 candidate family already exists.');
end

v1=readtable(fullfile(out_root,'A09_candidate_scores_ALL.csv'),'Delimiter',',');
v1.band=string(v1.band);
supports=readtable(fullfile(cfg.output_root,'07_resolution_supports', ...
    'A07_frozen_support_summary.csv'),'Delimiter',',');
supports.hemisphere=string(supports.hemisphere);
[matched,loc]=ismember(v1.support_id,supports.support_id);
if ~all(matched),error('Candidate/support mismatch.');end
v1.n_vertices=supports.n_vertices(loc);
v1.hemisphere=supports.hemisphere(loc);
v1.atlas_overlap=string(supports.atlas_overlap(loc));
v1.eligible=v1.n_vertices>=cfg.candidate_min_support_vertices;

component_names={'reliability_score','prevalence_score','precision_score','separability_score'};
eligible=find(v1.eligible);
for i=1:numel(component_names)
    source=v1.(component_names{i})(eligible);
    scaled=tiedrank(source)/numel(source);
    target_name=[component_names{i} '_percentile'];
    v1.(target_name)=nan(height(v1),1);
    v1.(target_name)(eligible)=scaled;
end
w=cfg.candidate_score_weights;
v1.candidate_score_V2=w.reliability*v1.reliability_score_percentile + ...
    w.prevalence*v1.prevalence_score_percentile + ...
    w.precision*v1.precision_score_percentile + ...
    w.separability*v1.separability_score_percentile;

ordered=sortrows(v1(v1.eligible,:),{'candidate_score_V2','support_id'}, ...
    {'descend','ascend'});
selected=false(height(ordered),1); used_supports=[]; n_selected=0;
for i=1:height(ordered)
    if sum(used_supports==ordered.support_id(i))>=cfg.candidate_max_bands_per_support
        continue;
    end
    selected(i)=true; used_supports(end+1)=ordered.support_id(i); %#ok<SAGROW>
    n_selected=n_selected+1;
    if n_selected==cfg.confirmatory_candidate_count,break;end
end
confirmatory_family_V2=ordered(selected,:);
confirmatory_family_V2.rank_V2=(1:height(confirmatory_family_V2))';
if height(confirmatory_family_V2)~=cfg.confirmatory_candidate_count
    error('Could not select the configured number of nonredundant candidates.');
end

decision=struct();
decision.v1_status='REJECTED_BEFORE_VALIDATION';
decision.v1_reason=['All eight V1 slots collapsed onto two small supports; ' ...
    'raw reliability and precision were near ceiling and did not contribute discriminatively.'];
decision.validation_opened_before_v2=false;
decision.v2_rules=struct('minimum_vertices',cfg.candidate_min_support_vertices, ...
    'maximum_bands_per_support',cfg.candidate_max_bands_per_support, ...
    'component_scaling',cfg.candidate_component_scaling, ...
    'weights',cfg.candidate_score_weights);
save(locked_mat,'confirmatory_family_V2','v1','decision','cfg','-v7.3');
writetable(v1,fullfile(out_root,'A09b_candidate_scores_V2_ALL.csv'));
writetable(confirmatory_family_V2,fullfile(out_root,'A09b_confirmatory_family_V2_LOCKED.csv'));
fprintf('Frozen V2 family: %d unique supports; V1 retained as rejected audit.\n', ...
    height(confirmatory_family_V2));
