function result = v371_run_conditioned_nested(dataset,cfg,y,folds,run_all_models)
%V371_RUN_CONDITIONED_NESTED Fixed-fold conditional model comparison.
if nargin<5,run_all_models=true;end
P=dataset.participants;y=double(y(:));n=numel(y);npatch=numel(dataset.patch_id);
if n~=cfg.expected_discovery_participants||any(string(P.assignment)~="discovery")
    error('V371:ValidationBoundary','Only the 225 discovery participants are permitted.');
end
q=cfg.spectral_basis_count;B=v37_spectral_basis(numel(dataset.frequency_hz),q);
S=double(dataset.average_relative_log_spectrum);
coeff=reshape(reshape(S,n*npatch,[])*B,n,npatch,q);
[Z,nuisance_names]=v371_nuisance_matrix(P);[Q,qc_names]=v371_qc_features(dataset);

names=["intercept","demographic","qc_only","neural_only","combined"];
pred_sum=zeros(n,numel(names));pred_count=zeros(n,numel(names));
selection_combined=zeros(npatch,1);selection_neural=zeros(npatch,1);eligible_count=zeros(npatch,1);
coefficient_combined=zeros(npatch,1);coefficient_neural=zeros(npatch,1);fold_rows=table();

for r=1:cfg.outer_repeats
    for o=1:cfg.outer_folds
        test=folds.outer_fold(:,r)==o;train=~test;
        if numel(unique(y(train)))<2||numel(unique(y(test)))<2
            error('V371:FoldClass','A locked outer fold lacks one class.');
        end
        eligible=local_eligibility(dataset,coeff,train,cfg);eligible_count=eligible_count+eligible;
        patch_ids=find(eligible);X=reshape(permute(coeff(:,patch_ids,:),[1 3 2]),n,[]);
        groups=repelem((1:numel(patch_ids))',q);inner=folds.inner_fold{r,o};

        p0=ones(sum(test),1)*mean(y(train));
        pred_sum(test,1)=pred_sum(test,1)+p0;pred_count(test,1)=pred_count(test,1)+1;

        [Zt,Zv]=v37_prepare_matrix(Z,train,test);
        dm=v37_ridge_logistic(Zt,y(train),cfg.demographic_ridge);
        pd=local_sigmoid([ones(sum(test),1),Zv]*dm.beta);
        pred_sum(test,2)=pred_sum(test,2)+pd;pred_count(test,2)=pred_count(test,2)+1;

        if run_all_models
            [Qt,Qv]=v37_prepare_matrix(Q,train,test);
            qm=v37_ridge_logistic(Qt,y(train),cfg.qc_ridge);
            pq=local_sigmoid([ones(sum(test),1),Qv]*qm.beta);
            pred_sum(test,3)=pred_sum(test,3)+pq;pred_count(test,3)=pred_count(test,3)+1;

            nf=v371_fit_sparse_tuned(X,zeros(n,0),y,train,test,inner,groups,cfg);
            pn=nf.probability;pred_sum(test,4)=pred_sum(test,4)+pn;
            pred_count(test,4)=pred_count(test,4)+1;
            gn=local_group_norm(nf.model.beta,groups,numel(patch_ids));
            sn=gn>cfg.selection_coefficient_tolerance;
            selection_neural(patch_ids(sn))=selection_neural(patch_ids(sn))+1;
            coefficient_neural(patch_ids)=coefficient_neural(patch_ids)+gn;
        else
            pq=nan(sum(test),1);pn=nan(sum(test),1);
            nf=struct('alpha',NaN,'lambda_fraction',NaN,'lambda',NaN);
        end

        cf=v371_fit_sparse_tuned(X,Z,y,train,test,inner,groups,cfg);
        pc=cf.probability;pred_sum(test,5)=pred_sum(test,5)+pc;pred_count(test,5)=pred_count(test,5)+1;
        gc=local_group_norm(cf.model.beta,groups,numel(patch_ids));sc=gc>cfg.selection_coefficient_tolerance;
        selection_combined(patch_ids(sc))=selection_combined(patch_ids(sc))+1;
        coefficient_combined(patch_ids)=coefficient_combined(patch_ids)+gc;

        row=table(r,o,sum(train),sum(test),sum(eligible),sum(sc), ...
            cf.alpha,cf.lambda_fraction,cf.lambda,v37_auc(y(test),pc),local_logloss(y(test),pc), ...
            v37_auc(y(test),pd),local_logloss(y(test),pd), ...
            v37_auc(y(test),pn),local_logloss(y(test),pn), ...
            v37_auc(y(test),pq),local_logloss(y(test),pq), ...
            'VariableNames',{'repeat','outer_fold','n_train','n_test','n_eligible_patches', ...
            'n_selected_combined','combined_alpha','combined_lambda_fraction','combined_lambda', ...
            'combined_AUC','combined_log_loss','demographic_AUC','demographic_log_loss', ...
            'neural_AUC','neural_log_loss','qc_AUC','qc_log_loss'});
        fold_rows=[fold_rows;row]; %#ok<AGROW>
        fprintf('repeat %d fold %d: combined selected=%d AUC=%.3f deltaLL=%.4f\n', ...
            r,o,sum(sc),row.combined_AUC,row.demographic_log_loss-row.combined_log_loss);
    end
end

probability=pred_sum./max(pred_count,1);metrics=struct();
for i=1:numel(names)
    if all(pred_count(:,i)>0),metrics.(names(i))=v371_metrics(y,probability(:,i));else,metrics.(names(i))=[];end
end
den=max(eligible_count,1);
result=struct('pipeline_version',cfg.pipeline_version,'y',y,'model_names',names, ...
    'probability',probability,'prediction_count',pred_count,'metrics',metrics, ...
    'fold_results',fold_rows,'patch_id',dataset.patch_id,'eligible_count',eligible_count, ...
    'combined_selection_count',selection_combined, ...
    'combined_selection_frequency',selection_combined./den, ...
    'combined_mean_coefficient_magnitude',coefficient_combined./den, ...
    'neural_selection_count',selection_neural, ...
    'neural_selection_frequency',selection_neural./den, ...
    'neural_mean_coefficient_magnitude',coefficient_neural./den, ...
    'spectral_basis',B,'nuisance_names',{nuisance_names},'qc_names',{qc_names}, ...
    'primary_incremental_log_loss',metrics.demographic.log_loss-metrics.combined.log_loss, ...
    'secondary_incremental_AUC',metrics.combined.AUC-metrics.demographic.AUC, ...
    'validation_participants_read',0,'run_all_models',run_all_models);
end

function eligible=local_eligibility(dataset,coeff,train,cfg)
coverage=mean(all(isfinite(coeff(train,:,:)),3),1);coverage=coverage(:);
reliability=median(double(dataset.technical.split_half_spectral_correlation(train,:)),1,'omitnan');reliability=reliability(:);
rankv=median(double(dataset.technical.regional_mode_rank(train,:)),1,'omitnan');rankv=rankv(:);
fn=median(double(dataset.technical.filter_norm(train,:)),1,'omitnan');fn=fn(:);
eligible=coverage>=cfg.minimum_participant_coverage & ...
    reliability>=cfg.minimum_median_split_half_spectral_correlation & ...
    rankv>=cfg.minimum_median_regional_mode_rank & fn>=cfg.minimum_filter_norm;
end
function g=local_group_norm(beta,groups,n),g=zeros(n,1);for i=1:n,g(i)=norm(beta(groups==i));end;end
function p=local_sigmoid(x),p=1./(1+exp(-max(min(x,35),-35)));end
function l=local_logloss(y,p)
if any(~isfinite(p)),l=NaN;return;end
p=min(max(p(:),1e-8),1-1e-8);y=y(:);l=-mean(y.*log(p)+(1-y).*log(1-p));
end
