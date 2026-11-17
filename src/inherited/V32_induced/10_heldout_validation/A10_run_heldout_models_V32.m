%% Run the locked mixed models in validation participants only.
clear; clc;
pipeline_root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root,'lib'));
cfg=v32_setup();
out_root=fullfile(cfg.output_root,'10_heldout_validation');
if ~exist(out_root,'dir'),mkdir(out_root);end
results_csv=fullfile(out_root,'A10_heldout_primary_results.csv');
if isfile(results_csv)
    error('V32:ValidationAlreadyRun','Validation results already exist: %s',results_csv);
end

candidates=readtable(fullfile(cfg.output_root,'09_reliability_candidates', ...
    'A09b_confirmatory_family_V2_LOCKED.csv'),'Delimiter',',');
candidates.band=string(candidates.band);
metrics=readtable(fullfile(cfg.output_root,'08_support_metrics', ...
    'A08_frozen_support_recording_metrics.csv'),'Delimiter',',');
metrics.subject_id=string(metrics.subject_id); metrics.group=string(metrics.group);
metrics.condition=string(metrics.condition); metrics.assignment=string(metrics.assignment);
metrics.band=string(metrics.band); metrics=metrics(metrics.assignment=="validation",:);

split=readtable(fullfile(cfg.output_root,'05_frozen_split', ...
    'A05_participant_split_LOCKED.csv'),'Delimiter',',');
split.subject_id=string(split.subject_id); split.sex=string(split.sex);
qc=readtable(fullfile(cfg.output_root,'03_subject_maps','A03_recording_band_QC.csv'),'Delimiter',',');
qc.subject_id=string(qc.subject_id); qc.condition=string(qc.condition); qc.band=string(qc.band);

all_results=table(); model_audit=table();
for i=1:height(candidates)
    rows=metrics.band==candidates.band(i) & metrics.support_id==candidates.support_id(i);
    data=metrics(rows,{'subject_id','group','condition','mean_percentile_log_energy'});
    [ok,loc]=ismember(data.subject_id,split.subject_id);
    if ~all(ok),error('Missing split covariates.');end
    data.age=split.age(loc); data.sex=split.sex(loc);
    key=data.subject_id+"|"+data.condition+"|"+candidates.band(i);
    qkey=qc.subject_id+"|"+qc.condition+"|"+qc.band;
    [ok,qloc]=ismember(key,qkey);
    if ~all(ok),error('Missing recording QC covariates.');end
    data.n_good_trials=qc.n_good_trials(qloc); data.inverse_VE=qc.inverse_VE(qloc);
    data.subject_id=categorical(data.subject_id);
    data.group=reordercats(categorical(data.group),{'HC','MDD'});
    data.condition=reordercats(categorical(data.condition),{'restEC','restEO'});
    data.sex=categorical(data.sex);
    formula=['mean_percentile_log_energy ~ group*condition + age + sex + ' ...
        'n_good_trials + inverse_VE + (1|subject_id)'];
    lme=fitlme(data,formula,'FitMethod','REML');
    C=lme.Coefficients;
    names=string(C.Name);
    diagnosis=find(contains(names,"group_MDD") & ~contains(names,":"),1);
    interaction=find(contains(names,"group_MDD") & contains(names,"condition_restEO"),1);
    if isempty(diagnosis)||isempty(interaction)
        error('Expected diagnosis coefficients were not found for candidate %d.',i);
    end
    terms=[diagnosis interaction]; labels=["diagnosis_MDD" "diagnosis_by_restEO"];
    for t=1:2
        j=terms(t);
        row=table(candidates.rank_V2(i),candidates.band(i),candidates.support_id(i), ...
            labels(t),C.Estimate(j),C.SE(j),C.DF(j),C.tStat(j),C.pValue(j), ...
            C.Lower(j),C.Upper(j),height(data),numel(categories(removecats(data.subject_id))), ...
            'VariableNames',{'candidate_rank','band','support_id','term','estimate', ...
            'standard_error','df','t_statistic','p_value','ci_lower','ci_upper', ...
            'n_recordings','n_participants'});
        all_results=[all_results;row]; %#ok<AGROW>
    end
    a=table(candidates.rank_V2(i),candidates.band(i),candidates.support_id(i), ...
        string(lme.Formula.char),lme.ModelCriterion.AIC,lme.ModelCriterion.BIC, ...
        'VariableNames',{'candidate_rank','band','support_id','formula','AIC','BIC'});
    model_audit=[model_audit;a]; %#ok<AGROW>
end

all_results.p_holm=holm_adjust(all_results.p_value);
all_results.reject_holm_0_05=all_results.p_holm<=0.05;
writetable(all_results,results_csv);
writetable(model_audit,fullfile(out_root,'A10_model_fit_audit.csv'));
save(fullfile(out_root,'A10_heldout_primary_results.mat'), ...
    'all_results','model_audit','candidates','cfg','-v7.3');
fprintf('Held-out models complete: %d/%d Holm-significant primary tests.\n', ...
    sum(all_results.reject_holm_0_05),height(all_results));

function adjusted=holm_adjust(p)
[sorted,order]=sort(p); m=numel(p); raw=(m-(1:m)'+1).*sorted;
monotone=cummax(raw); monotone=min(monotone,1); adjusted=zeros(size(p));
adjusted(order)=monotone;
end
