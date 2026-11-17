function status=v35_discovery_recordings(cfg)
status=readtable(fullfile(cfg.project_root,'derivatives','V33_broadband_mesh', ...
    '02_recording_maps','A02_extraction_status.csv'),'Delimiter',',');
for v={'subject_id','group','condition','source_file','status'},status.(v{1})=string(status.(v{1}));end
status=status(ismember(status.status,["OK","SKIPPED_EXISTS"]),:);
split=readtable(fullfile(cfg.project_root,'derivatives','V32_induced', ...
    '05_frozen_split','A05_participant_split_LOCKED.csv'),'Delimiter',',');
split.subject_id=string(split.subject_id);split.assignment=string(split.assignment);
[ok,loc]=ismember(status.subject_id,split.subject_id);
if ~all(ok),error('V35:SplitJoin','Recording-to-split join failed.');end
status.assignment=split.assignment(loc);status=status(status.assignment=="discovery",:);
status=sortrows(status,{'subject_id','condition'});
status=status(1:min(height(status),cfg.max_recordings),:);
end
