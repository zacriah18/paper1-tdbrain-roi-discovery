%% Independent conditional-permutation worker using one-file-per-permutation shards.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'03_permutation');shards=fullfile(out,'shards');
if ~exist(shards,'dir'),mkdir(shards);end
worker_id=str2double(getenv('TDBRAIN_V371_WORKER_ID'));
worker_count=str2double(getenv('TDBRAIN_V371_WORKER_COUNT'));
start_index=str2double(getenv('TDBRAIN_V371_START_INDEX'));
if ~isfinite(worker_id)||~isfinite(worker_count)||worker_id<1||worker_id>worker_count
    error('V371:WorkerConfig','Invalid worker id/count environment.');
end
if ~isfinite(start_index),start_index=cfg.permutation_shard_start_index;end

D=load(fullfile(cfg.project_root,'derivatives','V37_DCM_concordant_ROI_discovery', ...
    '03_participant_features','A03_participant_spectral_landscapes.mat'),'dataset');dataset=D.dataset;P=dataset.participants;
F=load(fullfile(cfg.output_root,'01_folds','A01_locked_nested_folds.mat'),'folds');folds=F.folds;
O=load(fullfile(cfg.output_root,'02_conditioned_models','A02_conditioned_nested_models.mat'),'result');
observed_incremental_log_loss=O.result.primary_incremental_log_loss;
observed_incremental_AUC=O.result.secondary_incremental_AUC;
if height(P)~=cfg.expected_discovery_participants||any(string(P.assignment)~="discovery")
    error('V371:ValidationBoundary','Parallel worker permits only 225 discovery participants.');
end
y=double(string(P.group)=="MDD");indices=(start_index+worker_id-1):worker_count:cfg.permutation_count;
fprintf('V37.1 permutation worker %d/%d assigned %d permutations, starting at %d; validation read=0.\n', ...
    worker_id,worker_count,numel(indices),start_index);
for p=indices
    final_file=fullfile(shards,sprintf('permutation_%04d.mat',p));
    if exist(final_file,'file'),fprintf('worker %d skipping completed permutation %d\n',worker_id,p);continue;end
    seed=cfg.permutation_seed+10000*p;[yp,meta]=v371_conditional_permutation(y,P,seed,folds.outer_fold);
    tic;rp=v371_run_conditioned_nested(dataset,cfg,yp,folds,false);elapsed_seconds=toc;
    permutation_index=p;incremental_log_loss=rp.primary_incremental_log_loss;
    incremental_AUC=rp.secondary_incremental_AUC;combined_log_loss=rp.metrics.combined.log_loss;
    combined_AUC=rp.metrics.combined.AUC;permutation_attempts=meta.attempts;
    validation_participants_read=0;solver_implementation=string(cfg.solver_implementation);
    temp_file=fullfile(shards,sprintf('permutation_%04d_worker_%02d.tmp.mat',p,worker_id));
    save(temp_file,'permutation_index','incremental_log_loss','incremental_AUC', ...
        'combined_log_loss','combined_AUC','seed','permutation_attempts','elapsed_seconds', ...
        'validation_participants_read','solver_implementation','-v7.3');
    [ok,message]=movefile(temp_file,final_file,'f');if ~ok,error('V371:ShardCommit','%s',message);end
    fprintf('worker %d permutation %d/%d COMPLETE deltaLL=%.4f deltaAUC=%.4f seconds=%.1f\n', ...
        worker_id,p,cfg.permutation_count,incremental_log_loss,incremental_AUC,elapsed_seconds);
end
fprintf('V37.1 permutation worker %d COMPLETE; validation read=0.\n',worker_id);
