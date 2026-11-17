function DCM=v36_build_dcm_spec(cfg,recording,output_file)
nodes=readtable(cfg.node_manifest,'Delimiter',',');nodes=sortrows(nodes,'dcm_node_number');
if height(nodes)~=6,error('V36:Nodes','Expected exactly six frozen handoff nodes.');end
H=v36_connectivity_hypotheses();parent=find(H.names==cfg.parent_hypothesis,1);
if isempty(parent),error('V36:Hypothesis','Parent hypothesis not found.');end
D=spm_eeg_load(char(recording.source_file));t=time(D,[],'ms');
if t(1)>cfg.time_window_ms(1)+1||t(end)<cfg.time_window_ms(2)-1
    error('V36:TimeWindow','Recording does not cover frozen %g-%g ms window.',cfg.time_window_ms);
end
DCM=struct();DCM.name=char(output_file);DCM.xY.Dfile=char(recording.source_file);DCM.xY.modality='EEG';
if ismember('dcm_name',nodes.Properties.VariableNames),DCM.Sname=cellstr(string(nodes.dcm_name));else,DCM.Sname={'L_mSFG','R_MFG_IFG','L_ITG_MTG','R_AnG_SPL_MOG','L_AnG_MOG','R_ITG_MTG'};end
DCM.Lpos=[nodes.x';nodes.y';nodes.z'];DCM.A=H.A(parent,:);DCM.B={};DCM.C=sparse(6,0);DCM.xU.X=sparse(1,0);
DCM.options.analysis=cfg.dcm_analysis;DCM.options.model=cfg.neuronal_model;DCM.options.spatial=cfg.spatial_model;
DCM.options.trials=1;DCM.options.Tdcm=cfg.time_window_ms;DCM.options.Fdcm=cfg.frequency_window_hz;
DCM.options.D=cfg.time_decimation;DCM.options.h=cfg.detrend_terms;DCM.options.han=double(cfg.hanning);
DCM.options.Nmodes=cfg.channel_modes;DCM.options.DATA=1;DCM.options.location=0;DCM.options.symmetry=0;
DCM.M.dipfit.radius=cfg.patch_radius_mm;DCM.M.dipfit.Nm=cfg.regional_spatial_modes;DCM.M.Nmax=cfg.max_iterations;
DCM.V36=struct('pipeline_version',cfg.pipeline_version,'hypothesis',H.names(parent), ...
    'hypothesis_description',H.description(parent),'subject_id',string(recording.subject_id), ...
    'group',string(recording.group),'condition',string(recording.condition), ...
    'focal_node',"L_mSFG",'focal_v34_rank',nodes.candidate_rank(1), ...
    'node_patch_ids',nodes.patch_id(:),'selection_uses_class_metrics',false, ...
    'selection_uses_connectivity_metrics',false,'source_file',string(recording.source_file));
end
