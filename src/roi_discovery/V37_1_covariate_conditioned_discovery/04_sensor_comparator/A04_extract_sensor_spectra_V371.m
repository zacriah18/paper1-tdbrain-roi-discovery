%% Extract sensor comparator spectra from discovery recordings only.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'04_sensor_comparator');maps=fullfile(out,'maps');
if ~exist(maps,'dir'),mkdir(maps);end
status=v37_discovery_recordings(cfg);n=height(status);
run_status=status(:,{'subject_id','group','condition','source_file'});
run_status.output_file=strings(n,1);run_status.status=repmat("PENDING",n,1);
run_status.message=strings(n,1);run_status.elapsed_seconds=nan(n,1);
for r=1:n
    tic;basename=status.subject_id(r)+"_"+status.group(r)+"_"+status.condition(r)+"_V371_sensor.mat";
    file=fullfile(maps,char(basename));run_status.output_file(r)=string(file);
    if cfg.resume&&exist(file,'file'),run_status.status(r)="SKIPPED_EXISTS";run_status.elapsed_seconds(r)=toc;continue;end
    try
        D=spm_eeg_load(char(status.source_file(r)));spectral=v371_sensor_spectra(D,cfg);
        result=struct('pipeline_version',cfg.pipeline_version,'subject_id',status.subject_id(r), ...
            'group',status.group(r),'condition',status.condition(r),'source_file',status.source_file(r), ...
            'spectral',spectral,'feature_role',"sensor-level spectral comparator; no source operator");
        save(file,'result','cfg','-v7.3');run_status.status(r)="OK";
    catch ME,run_status.status(r)="ERROR";run_status.message(r)=string(ME.identifier)+": "+string(ME.message);end
    run_status.elapsed_seconds(r)=toc;
    writetable(run_status,fullfile(out,'A04_sensor_extraction_status.csv'));
    fprintf('%d/%d %s %s %s (%.1fs)\n',r,n,status.subject_id(r),status.condition(r),run_status.status(r),run_status.elapsed_seconds(r));
end
writetable(run_status,fullfile(out,'A04_sensor_extraction_status.csv'));
save(fullfile(out,'A04_sensor_extraction_status.mat'),'run_status','cfg','-v7.3');
