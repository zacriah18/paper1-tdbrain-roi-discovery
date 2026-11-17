function DCM=v371_build_four_node_dcm_spec(cfg,recording,output_file)
%V371_BUILD_FOUR_NODE_DCM_SPEC Build the frozen four-node parent CSD model.
nodes=readtable(fullfile(cfg.output_root,'05_peer_set_comparison','A08_DCM_candidate_ROI_set.csv'),'Delimiter',',');
frozen=[385;5;261;314];[ok,loc]=ismember(frozen,nodes.patch_id);
if ~all(ok),error('V371:DCMNodes','Frozen DCM node file does not contain the four locked patches.');end
nodes=nodes(loc,:);H=v371_four_node_hypotheses();parent=4;
source_file=local_recording_value(recording,{'source_file','sourceFile','SourceFile'});
subject_id=local_recording_value(recording,{'subject_id','subjectId','SubjectId'});
group=local_recording_value(recording,{'group','Group'});
condition=local_recording_value(recording,{'condition','Condition'});
DCM=struct();DCM.name=char(output_file);DCM.xY.Dfile=char(source_file);DCM.xY.modality='EEG';
DCM.Sname={'R_Occipital','L_Auditory_Insula','R_Entorhinal_PHG','R_Precuneus_PCC'};
DCM.Lpos=[nodes.x';nodes.y';nodes.z'];DCM.A=H.A(parent,:);DCM.B={};DCM.C=sparse(4,0);DCM.xU.X=sparse(1,0);
DCM.options.analysis='CSD';DCM.options.model='CMC';DCM.options.spatial='IMG';DCM.options.trials=1;
DCM.options.Tdcm=[0 3992];DCM.options.Fdcm=[4 45];DCM.options.D=1;DCM.options.h=1;DCM.options.han=0;
DCM.options.Nmodes=cfg.peer_joint_channel_modes;DCM.options.DATA=1;DCM.options.location=0;DCM.options.symmetry=0;
DCM.M.dipfit.radius=cfg.patch_radius_mm;DCM.M.dipfit.Nm=cfg.regional_spatial_modes;DCM.M.Nmax=128;
DCM.V371=struct('pipeline_version',cfg.peer_pipeline_version,'hypothesis',H.names(parent), ...
    'hypothesis_description',H.description(parent),'subject_id',string(subject_id), ...
    'group',string(group),'condition',string(condition), ...
    'node_patch_ids',frozen,'selection_stage','frozen before validation access', ...
    'validation_role','pre-DCM observability audit; no connectivity inference');
end

function value=local_recording_value(recording,candidates)
names=fieldnames(recording);
for i=1:numel(candidates)
    hit=find(strcmpi(names,candidates{i}),1);
    if ~isempty(hit),value=recording.(names{hit});return;end
end
error('V371:RecordingField','Missing recording field. Expected one of: %s',strjoin(candidates,', '));
end
