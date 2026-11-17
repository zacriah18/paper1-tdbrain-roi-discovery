%% Paired participant-bootstrap uncertainty for already-frozen predictions.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'06_heldout_validation');
V=load(fullfile(out,'A11_frozen_validation_results.mat'),'validation');validation=V.validation;
P=validation.prediction;y=double(string(P.group)=="MDD");p0=P.demographic_probability;
models=["primary_K1","secondary_DCM_K4"];columns=["primary_probability","secondary_DCM_probability"];
B=10000;rng(cfg.validation_fixed_permutation_seed+200000,'twister');rows=table();
for m=1:numel(models)
    p1=P.(columns(m));obs_ll=mean(local_loss(y,p0)-local_loss(y,p1));obs_auc=v37_auc(y,p1)-v37_auc(y,p0);
    boot_ll=zeros(B,1);boot_auc=zeros(B,1);hc=find(y==0);mdd=find(y==1);
    for b=1:B
        idx=[hc(randi(numel(hc),numel(hc),1));mdd(randi(numel(mdd),numel(mdd),1))];
        boot_ll(b)=mean(local_loss(y(idx),p0(idx))-local_loss(y(idx),p1(idx)));
        boot_auc(b)=v37_auc(y(idx),p1(idx))-v37_auc(y(idx),p0(idx));
    end
    ll_ci=prctile(boot_ll,[2.5 97.5]);auc_ci=prctile(boot_auc,[2.5 97.5]);
    rows=[rows;table(models(m),obs_ll,ll_ci(1),ll_ci(2),obs_auc,auc_ci(1),auc_ci(2),B, ...
        'VariableNames',{'model','incremental_log_loss','incremental_log_loss_CI_low', ...
        'incremental_log_loss_CI_high','incremental_AUC','incremental_AUC_CI_low', ...
        'incremental_AUC_CI_high','participant_bootstrap_count'})]; %#ok<AGROW>
end
writetable(rows,fullfile(out,'A11b_validation_uncertainty.csv'));
save(fullfile(out,'A11b_validation_uncertainty.mat'),'rows','cfg','-v7.3');
fprintf('VALIDATION UNCERTAINTY AUDIT COMPLETE.\n');
function loss=local_loss(y,p),p=min(max(p(:),1e-8),1-1e-8);loss=-(y(:).*log(p)+(1-y(:)).*log(1-p));end
