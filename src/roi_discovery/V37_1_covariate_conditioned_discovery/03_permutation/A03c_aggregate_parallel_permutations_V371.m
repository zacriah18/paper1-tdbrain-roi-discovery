%% Aggregate legacy and independent permutation shards without refitting.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'00_config'));addpath(fullfile(root,'lib'));
cfg=v371_config();out=fullfile(cfg.output_root,'03_permutation');shards=fullfile(out,'shards');n=cfg.permutation_count;
null_incremental_log_loss=nan(n,1);null_incremental_AUC=nan(n,1);null_combined_log_loss=nan(n,1);
null_combined_AUC=nan(n,1);elapsed_seconds=nan(n,1);source=strings(n,1);
permutation_seed=nan(n,1);permutation_attempts=nan(n,1);
legacy=fullfile(out,'A03_conditional_full_pipeline_permutations.mat');
if exist(legacy,'file')
    L=load(legacy,'null_incremental_log_loss','null_incremental_AUC','null_combined_log_loss', ...
        'null_combined_AUC','permutation_seed','permutation_attempts');
    k=min(n,numel(L.null_incremental_log_loss));valid=find(isfinite(L.null_incremental_log_loss(1:k)));
    null_incremental_log_loss(valid)=L.null_incremental_log_loss(valid);null_incremental_AUC(valid)=L.null_incremental_AUC(valid);
    null_combined_log_loss(valid)=L.null_combined_log_loss(valid);null_combined_AUC(valid)=L.null_combined_AUC(valid);source(valid)="legacy";
    if isfield(L,'permutation_seed'),permutation_seed(valid)=L.permutation_seed(valid);end
    if isfield(L,'permutation_attempts'),permutation_attempts(valid)=L.permutation_attempts(valid);end
end
files=dir(fullfile(shards,'permutation_*.mat'));
for i=1:numel(files)
    z=load(fullfile(files(i).folder,files(i).name));p=z.permutation_index;
    if p<1||p>n,error('V371:ShardIndex','Invalid permutation index %d.',p);end
    null_incremental_log_loss(p)=z.incremental_log_loss;null_incremental_AUC(p)=z.incremental_AUC;
    null_combined_log_loss(p)=z.combined_log_loss;null_combined_AUC(p)=z.combined_AUC;
    elapsed_seconds(p)=z.elapsed_seconds;source(p)="shard";
    permutation_seed(p)=z.seed;permutation_attempts(p)=z.permutation_attempts;
end
O=load(fullfile(cfg.output_root,'02_conditioned_models','A02_conditioned_nested_models.mat'),'result');
observed_log_loss=O.result.primary_incremental_log_loss;observed_AUC=O.result.secondary_incremental_AUC;
completed=sum(isfinite(null_incremental_log_loss));exceed_log_loss=sum(null_incremental_log_loss>=observed_log_loss,'omitnan');
exceed_AUC=sum(null_incremental_AUC>=observed_AUC,'omitnan');
p_primary=(1+exceed_log_loss)/(1+completed);p_secondary=(1+exceed_AUC)/(1+completed);
summary=table(observed_log_loss,completed,exceed_log_loss,p_primary,observed_AUC,exceed_AUC,p_secondary, ...
    median(elapsed_seconds,'omitnan'),0,'VariableNames',{'observed_incremental_log_loss', ...
    'completed_valid_permutations','null_exceedances_log_loss','primary_empirical_p_value', ...
    'observed_incremental_AUC','null_exceedances_AUC','secondary_empirical_p_value', ...
    'median_shard_seconds','validation_participants_read'});
writetable(summary,fullfile(out,'A03c_parallel_permutation_interim_summary.csv'));
writetable(table((1:n)',null_incremental_log_loss,null_incremental_AUC,null_combined_log_loss, ...
    null_combined_AUC,permutation_seed,permutation_attempts,elapsed_seconds,source, ...
    'VariableNames',{'permutation_index','incremental_log_loss','incremental_AUC', ...
    'combined_log_loss','combined_AUC','permutation_seed','permutation_attempts', ...
    'elapsed_seconds','source'}), ...
    fullfile(out,'A03c_parallel_permutation_values.csv'));

% Reconstruct the exchangeability design and label vectors without fitting.
% This closes the audit gap left when the sequential runner was interrupted
% before it could write its block table.
D=load(fullfile(cfg.project_root,'derivatives','V37_DCM_concordant_ROI_discovery', ...
    '03_participant_features','A03_participant_spectral_landscapes.mat'),'dataset');P=D.dataset.participants;
F=load(fullfile(cfg.output_root,'01_folds','A01_locked_nested_folds.mat'),'folds');folds=F.folds;
y=double(string(P.group)=="MDD");[~,~,sex_binary]=v371_nuisance_matrix(P);
key=string(P.age_band)+"|sex="+string(sex_binary)+"|condition="+string(P.condition_availability);
[block,~,block_id]=unique(key,'stable');block_n=accumarray(block_id,1);
block_MDD=accumarray(block_id,y);block_HC=block_n-block_MDD;mixed=block_HC>0&block_MDD>0;
writetable(table(block,block_n,block_HC,block_MDD,mixed), ...
    fullfile(out,'A03c_conditional_permutation_blocks.csv'));
label_matrix=false(n,numel(y));recomputed_attempts=nan(n,1);seed_matches=true(n,1);attempt_matches=true(n,1);
for p=1:n
    expected_seed=cfg.permutation_seed+10000*p;
    [yp,meta]=v371_conditional_permutation(y,P,expected_seed,folds.outer_fold);
    label_matrix(p,:)=logical(yp(:)');recomputed_attempts(p)=meta.attempts;
    seed_matches(p)=permutation_seed(p)==expected_seed;
    attempt_matches(p)=permutation_attempts(p)==meta.attempts;
end
unique_label_vectors=size(unique(label_matrix,'rows'),1);
design_audit=table(n,numel(y),numel(block),sum(mixed),sum(block_n(mixed)), ...
    unique_label_vectors,sum(seed_matches),sum(attempt_matches),max(recomputed_attempts), ...
    'VariableNames',{'permutations','participants','exchangeability_blocks','mixed_label_blocks', ...
    'participants_in_mixed_blocks','unique_label_vectors','stored_seed_matches', ...
    'stored_attempt_matches','maximum_generation_attempts'});
writetable(design_audit,fullfile(out,'A03c_permutation_design_audit.csv'));
save(fullfile(out,'A03c_parallel_permutation_aggregate.mat'),'null_incremental_log_loss', ...
    'null_incremental_AUC','null_combined_log_loss','null_combined_AUC','permutation_seed', ...
    'permutation_attempts','elapsed_seconds','source','summary','design_audit','cfg','-v7.3');
fprintf('Aggregated %d/%d valid permutations: primary p=%.6f (%d exceedances); validation read=0.\n', ...
    completed,n,p_primary,exceed_log_loss);
