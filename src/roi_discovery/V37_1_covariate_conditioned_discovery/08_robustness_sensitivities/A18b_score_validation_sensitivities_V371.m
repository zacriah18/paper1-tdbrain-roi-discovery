%% Re-score frozen validation probabilities on prespecified QC/session subsets.
% This script never refits a coefficient and therefore does not alter the
% frozen validation model. The subset analyses are labelled sensitivities.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'lib'));
cfg = v371_setup();

validation_root = fullfile(cfg.output_root,'06_heldout_validation');
PRED = readtable(fullfile(validation_root,'A11_frozen_validation_predictions.csv'), ...
    'TextType','string');
V = load(fullfile(validation_root,'A10_validation_participant_spectral_landscapes.mat'),'dataset');
dataset = V.dataset; P = dataset.participants;
if ~isequal(string(P.subject_id),string(PRED.subject_id))
    error('V371:ValidationJoin','Validation feature and prediction orders differ.');
end

good_epochs = double(dataset.technical.good_epoch_count);
repeated_ids = string({'sub-88006161','sub-88009901','sub-88010981', ...
    'sub-88012461','sub-88017409','sub-88022089','sub-88023125','sub-88045713'});
masks = struct();
masks.high_qc = dataset.has_paired_conditions(:) & ...
    all(isfinite(good_epochs),2) & all(good_epochs >= 20,2);
masks.exclude_repeated_sessions = ~ismember(string(P.subject_id),repeated_ids);
definitions = struct( ...
    'high_qc','paired EC/EO and at least 20 retained epochs in each condition', ...
    'exclude_repeated_sessions','exclude all participants with multiple Stage-B eligible sessions');

names = fieldnames(masks);
for s = 1:numel(names)
    name = names{s}; include = masks.(name); Ps = P(include,:);
    y = double(string(Ps.group) == "MDD");
    p0 = double(PRED.demographic_probability(include));
    p1 = double(PRED.primary_probability(include));
    p4 = double(PRED.secondary_DCM_probability(include));
    m0 = v371_metrics(y,p0); m1 = v371_metrics(y,p1); m4 = v371_metrics(y,p4);
    delta1 = m0.log_loss - m1.log_loss; delta4 = m0.log_loss - m4.log_loss;
    [pvalue1,null1,audit1] = local_conditional_test(y,Ps,p0,p1, ...
        cfg.validation_fixed_permutation_count,cfg.validation_fixed_permutation_seed+300000+s*10000);
    [pvalue4,null4,audit4] = local_conditional_test(y,Ps,p0,p4, ...
        cfg.validation_fixed_permutation_count,cfg.validation_fixed_permutation_seed+400000+s*10000);
    [ci1low,ci1high] = local_bootstrap_ci(local_loss(y,p0)-local_loss(y,p1),y,5000, ...
        cfg.validation_fixed_permutation_seed+500000+s);
    [ci4low,ci4high] = local_bootstrap_ci(local_loss(y,p0)-local_loss(y,p4),y,5000, ...
        cfg.validation_fixed_permutation_seed+600000+s);

    rows = [local_row("demographic",m0,NaN,NaN,NaN); ...
        local_row("primary_K1",m1,delta1,ci1low,ci1high); ...
        local_row("secondary_DCM_K4",m4,delta4,ci4low,ci4high)];
    rows.conditional_p_value = [NaN;pvalue1;pvalue4];
    rows.sensitivity = repmat(string(name),height(rows),1);
    rows.definition = repmat(string(definitions.(name)),height(rows),1);
    rows.n_participants = repmat(sum(include),height(rows),1);
    rows.HC = repmat(sum(y==0),height(rows),1);
    rows.MDD = repmat(sum(y==1),height(rows),1);
    rows.coefficients_refit = false(height(rows),1);
    rows.validation_participants_read = repmat(height(P),height(rows),1);

    out = fullfile(cfg.output_root,'08_robustness_sensitivities',name);
    if ~exist(out,'dir'), mkdir(out); end
    writetable(rows,fullfile(out,'A18b_frozen_validation_sensitivity.csv'));
    manifest = P(:,{'subject_id','group','age','sex','age_band','condition_availability'});
    manifest.good_epochs_EC = good_epochs(:,1); manifest.good_epochs_EO = good_epochs(:,2);
    manifest.repeated_session_participant = ismember(string(P.subject_id),repeated_ids);
    manifest.included = include;
    writetable(manifest,fullfile(out,'A18b_validation_inclusion_manifest.csv'));
    audit = struct('primary',audit1,'secondary',audit4,'null_primary',null1, ...
        'null_secondary',null4,'coefficients_refit',false, ...
        'validation_participants_read',height(P));
    save(fullfile(out,'A18b_frozen_validation_sensitivity.mat'),'rows','audit','include','-v7.3');
    fprintf('%s validation sensitivity: n=%d primary deltaLL=%.5f p=%.6f; K4 deltaLL=%.5f p=%.6f; no refit.\n', ...
        name,sum(include),delta1,pvalue1,delta4,pvalue4);
end

function row = local_row(name,m,delta,lo,hi)
row = table(string(name),m.AUC,m.log_loss,m.Brier,m.balanced_accuracy, ...
    m.sensitivity,m.specificity,m.calibration_intercept,m.calibration_slope, ...
    delta,lo,hi,'VariableNames',{'model','AUC','log_loss','Brier', ...
    'balanced_accuracy','sensitivity_rate','specificity','calibration_intercept', ...
    'calibration_slope','incremental_log_loss','incremental_log_loss_CI_low', ...
    'incremental_log_loss_CI_high'});
end

function [pvalue,null,audit] = local_conditional_test(y,P,p0,p1,B,seed)
[~,~,sex_binary] = v371_nuisance_matrix(P);
key = string(P.age_band)+"|sex="+string(sex_binary)+"|condition="+string(P.condition_availability);
[block_name,~,block_id] = unique(key,'stable');
observed = mean(local_loss(y,p0)-local_loss(y,p1)); null = zeros(B,1);
block_size = accumarray(block_id,1); block_mdd = accumarray(block_id,y);
mixed = block_mdd>0 & block_mdd<block_size;
for b = 1:B
    stream = RandStream('mt19937ar','Seed',seed+b-1); yp = y;
    for k = 1:numel(block_name)
        idx = find(block_id==k);
        if numel(idx)>1, yp(idx)=y(idx(randperm(stream,numel(idx)))); end
    end
    null(b) = mean(local_loss(yp,p0)-local_loss(yp,p1));
end
pvalue = (1+sum(null>=observed))/(B+1);
audit = struct('blocks',block_name,'block_id',block_id,'block_size',block_size, ...
    'block_MDD_count',block_mdd,'mixed_label_blocks',sum(mixed), ...
    'participants_in_mixed_blocks',sum(block_size(mixed)),'permutations',B,'seed',seed);
end

function [lo,hi] = local_bootstrap_ci(values,y,B,seed)
rng(seed,'twister'); boot=zeros(B,1); a=find(y==0); b=find(y==1);
for i=1:B
    idx=[a(randi(numel(a),numel(a),1));b(randi(numel(b),numel(b),1))];
    boot(i)=mean(values(idx));
end
v=prctile(boot,[2.5 97.5]); lo=v(1); hi=v(2);
end

function loss = local_loss(y,p)
p=min(max(p(:),1e-8),1-1e-8); loss=-(y(:).*log(p)+(1-y(:)).*log(1-p));
end
