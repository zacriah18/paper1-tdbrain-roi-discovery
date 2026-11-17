%% Extract the frozen V37 regional representation in validation recordings.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'06_heldout_validation');maps_dir=fullfile(out,'maps');
if ~exist(maps_dir,'dir'),mkdir(maps_dir);end
manifest_file=fullfile(cfg.output_root,'05_peer_set_comparison','A08_validation_freeze_manifest.json');
if ~exist(manifest_file,'file'),error('V371:ValidationFreeze','Frozen manifest is missing.');end
manifest=jsondecode(fileread(manifest_file));
if string(manifest.status)~="FROZEN_FOR_VALIDATION"||manifest.validation_participants_read~=0
    error('V371:ValidationFreeze','Manifest is not eligible for validation access.');
end

P=load(fullfile(cfg.project_root,'derivatives','V37_DCM_concordant_ROI_discovery', ...
    '01_exact_IMG_patches','A01_exact_SPM_IMG_patch_universe.mat'),'patches');patches=P.patches;
status=readtable(fullfile(cfg.project_root,'derivatives','V33_broadband_mesh', ...
    '02_recording_maps','A02_extraction_status.csv'),'Delimiter',',');
for v={'subject_id','group','condition','source_file','status'},status.(v{1})=string(status.(v{1}));end
status=status(ismember(status.status,["OK","SKIPPED_EXISTS"]),:);
split=readtable(fullfile(cfg.project_root,'derivatives','V32_induced','05_frozen_split', ...
    'A05_participant_split_LOCKED.csv'),'Delimiter',',');
split.subject_id=string(split.subject_id);split.assignment=string(split.assignment);
[ok,loc]=ismember(status.subject_id,split.subject_id);if ~all(ok),error('V371:SplitJoin','Validation join failed.');end
status.assignment=split.assignment(loc);status=status(status.assignment=="validation",:);
status=sortrows(status,{'subject_id','condition'});
if numel(unique(status.subject_id))~=cfg.expected_validation_participants
    error('V371:ValidationCount','Expected 98 validation participants.');
end

n=height(status);run_status=status(:,{'subject_id','group','condition','source_file'});
run_status.output_file=strings(n,1);run_status.status=repmat("PENDING",n,1);
run_status.message=strings(n,1);run_status.elapsed_seconds=nan(n,1);
for r=1:n
    tic;basename=status.subject_id(r)+"_"+status.group(r)+"_"+status.condition(r)+"_V371_validation_node_spectra.mat";
    output_file=fullfile(maps_dir,char(basename));run_status.output_file(r)=string(output_file);
    if cfg.resume&&exist(output_file,'file')
        run_status.status(r)="SKIPPED_EXISTS";run_status.elapsed_seconds(r)=toc;continue
    end
    try
        D=spm_eeg_load(char(status.source_file(r)));
        region=v37_exact_img_filters(D,cfg,patches);spectral=v37_regional_spectra(D,cfg,region);
        result=struct('pipeline_version',cfg.peer_pipeline_version,'subject_id',status.subject_id(r), ...
            'group',status.group(r),'condition',status.condition(r),'source_file',status.source_file(r), ...
            'patch_id',(1:size(patches.membership,2))','spectral',spectral, ...
            'regional_rank',region.regional_rank,'regional_effective_rank',region.regional_effective_rank, ...
            'filter_norm',region.filter_norm,'mean_posterior_variance',region.mean_posterior_variance, ...
            'assignment',"validation",'freeze_manifest_sha256',string(manifest.sha256));
        save(output_file,'result','cfg','-v7.3');run_status.status(r)="OK";
    catch ME
        run_status.status(r)="ERROR";run_status.message(r)=string(ME.identifier)+": "+string(ME.message);
    end
    run_status.elapsed_seconds(r)=toc;
    writetable(run_status,fullfile(out,'A09_validation_extraction_status.csv'));
    fprintf('validation extraction %d/%d %s %s %s (%.1fs)\n',r,n,status.subject_id(r), ...
        status.condition(r),run_status.status(r),run_status.elapsed_seconds(r));
end
writetable(run_status,fullfile(out,'A09_validation_extraction_status.csv'));
save(fullfile(out,'A09_validation_extraction_status.mat'),'run_status','cfg','manifest','-v7.3');
if any(run_status.status=="ERROR"),error('V371:ValidationExtraction','%d validation recordings failed.',sum(run_status.status=="ERROR"));end
fprintf('VALIDATION EXTRACTION COMPLETE: %d recordings from 98 participants.\n',n);
