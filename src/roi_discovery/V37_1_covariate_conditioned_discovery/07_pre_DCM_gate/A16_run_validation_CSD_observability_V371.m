%% Subject-recording CSD visibility and joint-observability gate for frozen nodes.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'07_pre_DCM_gate');maps=fullfile(out,'csd_maps');
if ~exist(maps,'dir'),mkdir(maps);end
source=readtable(fullfile(cfg.output_root,'06_heldout_validation','A09_validation_extraction_status.csv'), ...
    'Delimiter',',','TextType','string','VariableNamingRule','preserve');
source=source(ismember(string(source.status),["OK","SKIPPED_EXISTS"]),:);
status=source(:,{'subject_id','group','condition','source_file'});n=height(status);
status.output_file=strings(n,1);status.status=repmat("PENDING",n,1);
status.message=strings(n,1);status.elapsed_seconds=nan(n,1);
for r=1:n
    tic;name=status.subject_id(r)+"_"+status.group(r)+"_"+status.condition(r)+"_V371_CSD_observability.mat";
    file=fullfile(maps,char(name));status.output_file(r)=string(file);
    if cfg.resume&&exist(file,'file')
        status.status(r)="SKIPPED_EXISTS";status.elapsed_seconds(r)=toc;
    else
        try
            recording=table2struct(status(r,{'subject_id','group','condition','source_file'}));
            audit=v371_csd_observability(cfg,recording);
            save(file,'audit','cfg','-v7.3');status.status(r)="OK";
        catch ME
            status.status(r)="ERROR";status.message(r)=string(ME.identifier)+": "+string(ME.message);
        end
        status.elapsed_seconds(r)=toc;
    end
    writetable(status,fullfile(out,'A16_CSD_observability_status.csv'));
    fprintf('%d/%d %s %s %s (%.1fs)\n',r,n,status.subject_id(r),status.condition(r),status.status(r),status.elapsed_seconds(r));
end
writetable(status,fullfile(out,'A16_CSD_observability_status.csv'));
save(fullfile(out,'A16_CSD_observability_status.mat'),'status','cfg','-v7.3');
local_aggregate(status,out,cfg);

function local_aggregate(status,out,cfg)
keep=ismember(status.status,["OK","SKIPPED_EXISTS"]);files=status.output_file(keep);
recording_rows=table();node_rows=table();pair_rows=table();
for r=1:numel(files)
    z=load(char(files(r)),'audit');a=z.audit;
    row=table(string(a.subject_id),string(a.group),string(a.condition),string(a.source_file), ...
        a.joint_dominant_rank,a.joint_effective_rank,a.joint_condition_number,a.channel_modes, ...
        a.minimum_unique_residual_norm,logical(a.numerical_noncollapse_pass), ...
        'VariableNames',{'subject_id','group','condition','source_file','joint_dominant_rank', ...
        'joint_effective_rank','joint_condition_number','channel_modes','minimum_unique_residual_norm', ...
        'numerical_noncollapse_pass'});
    recording_rows=[recording_rows;row]; %#ok<AGROW>
    t=a.node;t.subject_id=repmat(string(a.subject_id),height(t),1);t.group=repmat(string(a.group),height(t),1);
    t.condition=repmat(string(a.condition),height(t),1);t=movevars(t,{'subject_id','group','condition'},'Before',1);
    node_rows=[node_rows;t]; %#ok<AGROW>
    p=a.pair;p.subject_id=repmat(string(a.subject_id),height(p),1);p.group=repmat(string(a.group),height(p),1);
    p.condition=repmat(string(a.condition),height(p),1);p=movevars(p,{'subject_id','group','condition'},'Before',1);
    pair_rows=[pair_rows;p]; %#ok<AGROW>
end
writetable(recording_rows,fullfile(out,'A16_recording_joint_observability.csv'));
writetable(node_rows,fullfile(out,'A16_recording_node_visibility.csv'));
writetable(pair_rows,fullfile(out,'A16_recording_pair_overlap_and_CSD.csv'));
if isempty(recording_rows),return;end
summary=table(height(recording_rows),numel(unique(recording_rows.subject_id)),sum(recording_rows.condition=="restEC"), ...
    sum(recording_rows.condition=="restEO"),mean(recording_rows.numerical_noncollapse_pass), ...
    median(recording_rows.joint_effective_rank),prctile(recording_rows.joint_effective_rank,5), ...
    median(recording_rows.minimum_unique_residual_norm),prctile(recording_rows.minimum_unique_residual_norm,5), ...
    'VariableNames',{'recordings','participants','EC_recordings','EO_recordings','noncollapse_pass_rate', ...
    'median_joint_effective_rank','p05_joint_effective_rank','median_minimum_unique_residual', ...
    'p05_minimum_unique_residual'});
writetable(summary,fullfile(out,'A16_CSD_observability_summary.csv'));
save(fullfile(out,'A16_CSD_observability_results.mat'),'recording_rows','node_rows','pair_rows','summary','cfg','-v7.3');
end
