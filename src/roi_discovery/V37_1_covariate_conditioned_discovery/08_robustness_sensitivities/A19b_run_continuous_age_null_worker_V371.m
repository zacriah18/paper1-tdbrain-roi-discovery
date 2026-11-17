%% Run atomic shards of the frozen continuous-age parametric null.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'lib'));
cfg = v371_setup();

worker_id = str2double(getenv('TDBRAIN_V371_NULL_WORKER_ID'));
worker_count = str2double(getenv('TDBRAIN_V371_NULL_WORKER_COUNT'));
requested_count = str2double(getenv('TDBRAIN_V371_NULL_COUNT'));
if ~isfinite(worker_id), worker_id = 1; end
if ~isfinite(worker_count), worker_count = 1; end

out = fullfile(cfg.output_root,'08_robustness_sensitivities', ...
    'continuous_age_parametric_null');
freeze_file = fullfile(out,'A19a_continuous_age_null_freeze.mat');
if ~exist(freeze_file,'file')
    error('V371:MissingNullFreeze','Run A19a before null workers.');
end
L = load(freeze_file,'freeze','dataset','folds','cfg');
freeze = L.freeze; dataset = L.dataset; folds = L.folds; cfg = L.cfg;
if ~isfinite(requested_count), requested_count = freeze.bootstrap_count; end
requested_count = min(round(requested_count),freeze.bootstrap_count);
cfg.expected_discovery_participants = height(dataset.participants);

shard_dir = fullfile(out,'shards');
if ~exist(shard_dir,'dir'), mkdir(shard_dir); end
for b = worker_id:worker_count:requested_count
    target = fullfile(shard_dir,sprintf('bootstrap_%04d.mat',b));
    if exist(target,'file'), continue; end
    seed = freeze.bootstrap_seed + 10000*b;
    [yb,attempts] = local_generate(freeze.null_probability,seed,folds.outer_fold);
    tic;
    result = v371_run_conditioned_nested(dataset,cfg,yb,folds,false);
    elapsed_seconds = toc;
    entry = struct('bootstrap_index',b,'seed',seed,'attempts',attempts, ...
        'generated_label',logical(yb),'generated_MDD',sum(yb), ...
        'incremental_log_loss',result.primary_incremental_log_loss, ...
        'incremental_AUC',result.secondary_incremental_AUC, ...
        'elapsed_seconds',elapsed_seconds,'validation_participants_read',0);
    temporary = [tempname(shard_dir) '.mat'];
    save(temporary,'entry','-v7');
    [ok,message] = movefile(temporary,target,'f');
    if ~ok, error('V371:ShardMove','%s',message); end
    fprintf('continuous-age bootstrap %d/%d: MDD=%d deltaLL=%.5f deltaAUC=%.5f %.1fs\n', ...
        b,requested_count,sum(yb),entry.incremental_log_loss,entry.incremental_AUC,elapsed_seconds);
end
fprintf('Worker %d complete. validation read=0.\n',worker_id);

function [y,attempt] = local_generate(probability,seed,outer_fold)
probability = double(probability(:));
for attempt = 1:1000
    stream = RandStream('mt19937ar','Seed',seed + attempt - 1);
    y = double(rand(stream,numel(probability),1) < probability);
    if local_valid_outer(y,outer_fold), return; end
end
error('V371:NullGeneration','Could not generate class-valid labels in 1000 attempts.');
end

function valid = local_valid_outer(y,outer_fold)
valid = true;
for r = 1:size(outer_fold,2)
    for o = unique(outer_fold(:,r))'
        test = outer_fold(:,r) == o;
        if numel(unique(y(test))) < 2 || numel(unique(y(~test))) < 2
            valid = false; return;
        end
    end
end
end
