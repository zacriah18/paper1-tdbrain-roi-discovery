%% Bounded end-to-end synthetic test for the conditioned nested model.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'lib'));
addpath(fullfile(fileparts(root),'V37_DCM_concordant_ROI_discovery','lib'));
addpath(fullfile(root,'00_config'));
cfg = v371_config();
cfg.outer_repeats = 1; cfg.outer_folds = 2; cfg.inner_folds = 2;
cfg.alpha_grid = [0 0.5]; cfg.lambda_fraction_grid = [0.5 0.1];
cfg.sparse_max_iterations = 80; cfg.expected_discovery_participants = 225;

rng(371); n = 225; np = 8; nf = 18;
y = double(rand(n,1)>0.49);
age = 20 + 55*rand(n,1); sex = double(rand(n,1)>0.5);
group = repmat("HC",n,1); group(y==1) = "MDD";
age_band = string(discretize(age,[0 35 50 65 inf], ...
    'categorical',{'18-34','35-49','50-64','65+'}));
condition_availability = repmat("EC+EO",n,1);
subject_id = "synthetic_" + string((1:n)'); assignment = repmat("discovery",n,1);
participants = table(subject_id,group,age,sex,age_band,condition_availability,assignment);

frequency_hz = linspace(4,45,nf)';
average_relative_log_spectrum = randn(n,np,nf)*0.2;
average_relative_log_spectrum(y==1,2,4:7) = ...
    average_relative_log_spectrum(y==1,2,4:7) + 0.45;
technical = struct();
technical.split_half_spectral_correlation = 0.95 + 0.02*rand(n,np);
technical.regional_mode_rank = 6*ones(n,np);
technical.filter_norm = ones(n,np);
technical.mean_posterior_variance = 0.1 + 0.05*rand(n,np);
technical.good_epoch_count = 25 + randi(10,n,2);
dataset = struct('participants',participants,'patch_id',(1:np)', ...
    'frequency_hz',frequency_hz, ...
    'average_relative_log_spectrum',average_relative_log_spectrum, ...
    'technical',technical,'has_paired_conditions',true(n,1));

outer_fold = zeros(n,1); inner_fold = cell(1,2);
outer_fold(:,1) = v37_make_folds(y,sex,age_band,2,991);
for o = 1:2
    train = find(outer_fold(:,1)~=o);
    inner_fold{1,o} = v37_make_folds(y(train),sex(train),age_band(train),2,991+o);
end
folds = struct('outer_fold',outer_fold,'inner_fold',{inner_fold});
result = v371_run_conditioned_nested(dataset,cfg,y,folds,true);
assert(all(isfinite(result.probability(:))));
assert(isfinite(result.primary_incremental_log_loss));
assert(result.validation_participants_read==0);
[yp,permutation_meta] = v371_conditional_permutation(y,participants,12345,outer_fold);
assert(numel(yp)==n && permutation_meta.n_blocks>0);
permuted = v371_run_conditioned_nested(dataset,cfg,yp,folds,false);
assert(isfinite(permuted.primary_incremental_log_loss));
fprintf('V371_SYNTHETIC_OK combined_AUC=%.3f delta_logloss=%.4f\n', ...
    result.metrics.combined.AUC,result.primary_incremental_log_loss);
