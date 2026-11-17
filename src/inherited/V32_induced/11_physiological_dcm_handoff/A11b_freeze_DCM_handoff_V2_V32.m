%% Apply the pre-existing minimum-support-size rule to the DCM handoff.
clear; clc;
pipeline_root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root,'lib'));
cfg=v32_setup();
out_root=fullfile(cfg.output_root,'11_physiological_dcm_handoff');
output_csv=fullfile(out_root,'A11b_DCM_node_handoff_V2_LOCKED.csv');
if isfile(output_csv),error('V32:HandoffV2Exists','V2 handoff already exists.');end

A=load(fullfile(out_root,'A11_physiological_DCM_handoff_LOCKED.mat'), ...
    'shortlist','validation','similarity');
F=load(fullfile(cfg.output_root,'07_resolution_supports', ...
    'A07_frozen_resolution_supports_LOCKED.mat'),'frozen');
supports=F.frozen.support_table;
shortlist=A.shortlist;validation=A.validation;similarity=A.similarity;
coords=[supports.representative_x supports.representative_y supports.representative_z];

selected_rows=[];selected_supports=[];
for i=1:height(shortlist)
    s=shortlist.support_id(i);
    sr=supports(supports.support_id==s,:);
    v=validation(validation.discovery_rank==shortlist.discovery_rank(i),:);
    if ~v.replicated || sr.n_vertices<cfg.candidate_min_support_vertices,continue;end
    if ~isempty(selected_supports)
        if any(similarity(s,selected_supports)>cfg.dcm_max_profile_cosine),continue;end
        distance=sqrt(sum((coords(selected_supports,:)-coords(s,:)).^2,2));
        if any(distance<cfg.dcm_min_coordinate_distance_mm),continue;end
    end
    selected_rows(end+1)=i;selected_supports(end+1)=s; %#ok<AGROW>
    if numel(selected_rows)==cfg.dcm_max_nodes,break;end
end
if numel(selected_rows)<cfg.dcm_min_nodes
    error('V32:InsufficientDCMNodes','Only %d V2 nodes survived.',numel(selected_rows));
end

nodes=shortlist(selected_rows,:);
nodes.Properties.VariableNames{'band'}='evidence_band';
nodes.node_id=(1:height(nodes))';
[~,sloc]=ismember(nodes.support_id,supports.support_id);
nodes.hemisphere=supports.hemisphere(sloc);nodes.n_vertices=supports.n_vertices(sloc);
nodes.representative_x=supports.representative_x(sloc);
nodes.representative_y=supports.representative_y(sloc);
nodes.representative_z=supports.representative_z(sloc);
nodes.atlas_overlap=supports.atlas_overlap(sloc);
[~,vloc]=ismember(nodes.discovery_rank,validation.discovery_rank);
nodes.validation_cohen_dz=validation.cohen_dz(vloc);
nodes.validation_p_holm=validation.p_holm(vloc);
nodes.validation_ci_lower=validation.ci_lower(vloc);
nodes.validation_ci_upper=validation.ci_upper(vloc);
nodes.dcm_source_name="Node"+compose('%02d',nodes.node_id)+"_Support"+string(nodes.support_id);

decision=struct('v1_status','REJECTED_BEFORE_DCM_CONSTRUCTION', ...
    'reason',['V1 admitted supports below the pre-existing 50-vertex minimum; ' ...
    'V2 applies that rule without changing validation estimates or redundancy thresholds.'], ...
    'minimum_vertices',cfg.candidate_min_support_vertices);
writetable(nodes,output_csv);
save(fullfile(out_root,'A11b_DCM_node_handoff_V2_LOCKED.mat'), ...
    'nodes','decision','cfg','-v7.3');
fprintf('V2 DCM handoff frozen with %d nodes, all at least %d vertices.\n', ...
    height(nodes),cfg.candidate_min_support_vertices);
