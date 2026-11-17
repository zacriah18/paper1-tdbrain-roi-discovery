%% Extract one restartable broadband posterior-energy mesh per recording.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v33_setup();
eq=readtable(fullfile(cfg.output_root,'01_equivalence','A01_broadband_equivalence.csv'),'Delimiter',',');
if isempty(eq)||~all(eq.pass),error('Broadband equivalence gate has not passed.');end
out=fullfile(cfg.output_root,'02_recording_maps');maps=fullfile(out,'maps');if ~exist(maps,'dir'),mkdir(maps);end
inv=readtable(cfg.inventory_csv,'Delimiter',',','VariableNamingRule','preserve');
for v={'subject_id','group','condition','source_file','overall_status'},inv.(v{1})=string(inv.(v{1}));end
inv=inv(inv.overall_status=="OK",:);[inv,duplicate_audit]=v32_resolve_inventory_duplicates(inv,cfg);
writetable(duplicate_audit,fullfile(out,'A02_duplicate_audit.csv'));status=table();
for i=1:height(inv)
    file=string(fullfile(maps,char(inv.subject_id(i)+"_"+inv.group(i)+"_"+inv.condition(i)+"_V33_broadband.mat")));
    state="OK";message="";tic;
    try
        if isfile(file),state="SKIPPED_EXISTS";else
            D=spm_eeg_load(char(inv.source_file(i)));result=v33_compute_broadband_energy(D,cfg);
            result.subject_id=inv.subject_id(i);result.group=inv.group(i);result.condition=inv.condition(i);
            result.source_file=inv.source_file(i);result=rmfield(result,'model');save(char(file),'result','cfg','-v7.3');
        end
    catch ME,state="FAILED";message=regexprep(string(getReport(ME,'basic','hyperlinks','off')),'[\r\n]+',' | ');end
    r=table(inv.subject_id(i),inv.group(i),inv.condition(i),inv.source_file(i),file,state,message,toc, ...
        'VariableNames',{'subject_id','group','condition','source_file','output_file','status','error_message','elapsed_seconds'});
    status=[status;r];writetable(status,fullfile(out,'A02_extraction_status.csv')); %#ok<AGROW>
    fprintf('%d/%d %s %s %s\n',i,height(inv),inv.subject_id(i),inv.condition(i),state);
end
save(fullfile(out,'A02_extraction_status.mat'),'status','cfg');
