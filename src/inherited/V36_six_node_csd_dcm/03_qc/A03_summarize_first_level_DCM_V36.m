%% Summarize completed first-level models without group inference.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v36_setup();
out=fullfile(cfg.output_root,'03_qc');if ~exist(out,'dir'),mkdir(out);end
status=readtable(fullfile(cfg.output_root,'02_first_level','A02_first_level_run_status.csv'),'Delimiter',',');
for v={'subject_id','group','condition','output_file','status','message'},status.(v{1})=string(status.(v{1}));end
ok=ismember(status.status,["OK","OK_EXISTING"]);completed=status(ok,:);writetable(completed,fullfile(out,'A03_completed_first_level_models.csv'));
summary=groupsummary(status,{'group','condition'},'IncludeEmptyGroups',true,'IncludeMissingGroups',true, ...
    {'sum','median','min','max'},{'elapsed_seconds','free_energy','percent_variance_explained'});
writetable(summary,fullfile(out,'A03_first_level_QC_summary.csv'));
fid=fopen(fullfile(out,'A03_FIRST_LEVEL_QC_STATUS.md'),'w');fprintf(fid,'# V36 first-level CSD-DCM status\n\n');
fprintf(fid,'- Requested recordings: %d\n- Completed valid DCMs: %d\n- Errors: %d\n- Pending/running: %d\n',height(status),sum(ok),sum(status.status=="ERROR"),sum(ismember(status.status,["PENDING","RUNNING"])));
if any(ok),fprintf(fid,'- Median free energy: %.3f\n- Median descriptive spectral variance explained: %.2f%%\n- Median runtime: %.1f minutes\n',median(status.free_energy(ok),'omitnan'),median(status.percent_variance_explained(ok),'omitnan'),median(status.elapsed_seconds(ok),'omitnan')/60);end
fprintf(fid,'\nNo group or condition inference is performed here. Models must pass first-level QC before participant-aware PEB.\n');fclose(fid);
