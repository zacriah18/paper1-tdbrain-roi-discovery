function A02_run_first_level_CSD_DCM_V36
%% Resumable long-run first-level inversion of the H5 parent CSD-DCM.
clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v36_setup();
out=fullfile(cfg.output_root,'02_first_level');models=fullfile(out,'models');if ~exist(models,'dir'),mkdir(models);end
recordings=v36_discovery_recordings(cfg);n=height(recordings);if n==0,error('V36:Inventory','No recordings in requested row range.');end
subject_id=recordings.subject_id;group=recordings.group;condition=recordings.condition;source_file=recordings.source_file;
output_file=strings(n,1);status=repmat("PENDING",n,1);message=strings(n,1);elapsed_seconds=nan(n,1);free_energy=nan(n,1);
percent_variance_explained=nan(n,1);n_channel_modes=nan(n,1);n_frequencies=nan(n,1);completed_utc=strings(n,1);
for i=1:n
    folder=fullfile(models,char(subject_id(i)));if ~exist(folder,'dir'),mkdir(folder);end
    output_file(i)=fullfile(folder,sprintf('DCM_%s_%s_%s_H5_CMC_IMG.mat',subject_id(i),group(i),condition(i)));
end
checkpoint=fullfile(out,'A02_first_level_run_status.csv');
if exist(checkpoint,'file')
    old=readtable(checkpoint,'Delimiter',',');for v={'source_file','status','message','completed_utc'},old.(v{1})=string(old.(v{1}));end
    [ok,loc]=ismember(source_file,old.source_file);for i=find(ok)'
        status(i)=old.status(loc(i));message(i)=old.message(loc(i));elapsed_seconds(i)=old.elapsed_seconds(loc(i));free_energy(i)=old.free_energy(loc(i));
        percent_variance_explained(i)=old.percent_variance_explained(loc(i));n_channel_modes(i)=old.n_channel_modes(loc(i));n_frequencies(i)=old.n_frequencies(loc(i));completed_utc(i)=old.completed_utc(loc(i));
    end
end
for i=1:n
    if cfg.resume&&valid_dcm(output_file(i))
        status(i)="OK_EXISTING";[free_energy(i),percent_variance_explained(i),n_channel_modes(i),n_frequencies(i)]=read_qc(output_file(i));
        checkpoint_now(out,checkpoint,cfg,make_status());continue;
    end
    if status(i)=="ERROR"&&~cfg.retry_errors,continue;end
    status(i)="RUNNING";message(i)="";checkpoint_now(out,checkpoint,cfg,make_status());started=tic;
    try
        DCM=v36_build_dcm_spec(cfg,recordings(i,:),output_file(i));DCM=spm_dcm_csd(DCM); %#ok<NASGU>
        if ~valid_dcm(output_file(i)),error('V36:InvalidOutput','SPM returned without a valid saved DCM.');end
        status(i)="OK";[free_energy(i),percent_variance_explained(i),n_channel_modes(i),n_frequencies(i)]=read_qc(output_file(i));
    catch ME
        status(i)="ERROR";message(i)=string(ME.identifier)+": "+string(ME.message);
        errfile=fullfile(out,sprintf('ERROR_%s_%s.txt',subject_id(i),condition(i)));fid=fopen(errfile,'w');fprintf(fid,'%s\n',getReport(ME,'extended','hyperlinks','off'));fclose(fid);
    end
    elapsed_seconds(i)=toc(started);completed_utc(i)=string(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss Z'));
    checkpoint_now(out,checkpoint,cfg,make_status());
    fprintf('%d/%d %s %s %s %.1f min F=%.3f VE=%.2f%%\n',i,n,subject_id(i),condition(i),status(i),elapsed_seconds(i)/60,free_energy(i),percent_variance_explained(i));
end
checkpoint_now(out,checkpoint,cfg,make_status());

function run_status=make_status()
    run_status=table(subject_id,group,condition,source_file,output_file,status,message,elapsed_seconds,free_energy, ...
        percent_variance_explained,n_channel_modes,n_frequencies,completed_utc);
end
function checkpoint_now(out,checkpoint,cfg,run_status)
    writetable(run_status,checkpoint);save(fullfile(out,'A02_first_level_run_status.mat'),'run_status','cfg','-v7.3');
end
function ok=valid_dcm(file)
ok=false;if ~exist(file,'file'),return;end
try,S=load(char(file),'DCM');ok=isfield(S,'DCM')&&isfield(S.DCM,'Ep')&&isfield(S.DCM,'Cp')&&isfield(S.DCM,'F')&&isfinite(S.DCM.F);catch,ok=false;end
end
function [F,VE,nm,nf]=read_qc(file)
S=load(char(file),'DCM');D=S.DCM;F=double(D.F);y=spm_vec(D.xY.y);r=spm_vec(D.Rc);VE=100*(1-sum(abs(r).^2)/max(sum(abs(y-mean(y)).^2),eps));nm=size(D.M.U,2);nf=numel(D.xY.Hz);
end
end
