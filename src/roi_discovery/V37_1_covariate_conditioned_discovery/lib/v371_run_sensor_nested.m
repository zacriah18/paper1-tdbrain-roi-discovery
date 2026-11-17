function result=v371_run_sensor_nested(sensor,cfg,y,folds)
%V371_RUN_SENSOR_NESTED Locked-fold sensor-only and sensor+nuisance comparator.
P=sensor.participants;y=double(y(:));n=numel(y);nc=numel(sensor.channel_label);q=cfg.spectral_basis_count;
if n~=cfg.expected_discovery_participants||any(string(P.assignment)~="discovery")
    error('V371:ValidationBoundary','Sensor comparator permits only discovery participants.');
end
B=v37_spectral_basis(numel(sensor.frequency_hz),q);S=double(sensor.average_relative_log_spectrum);
coeff=reshape(reshape(S,n*nc,[])*B,n,nc,q);[Z,nuisance_names]=v371_nuisance_matrix(P);
names=["sensor_only","sensor_combined"];ps=zeros(n,2);pc=zeros(n,2);fold_rows=table();
selection=zeros(nc,1);eligible_count=zeros(nc,1);
for r=1:cfg.outer_repeats
    for o=1:cfg.outer_folds
        test=folds.outer_fold(:,r)==o;train=~test;
        coverage=squeeze(mean(all(isfinite(coeff(train,:,:)),3),1));
        eligible=coverage(:)>=cfg.sensor_minimum_channel_coverage;eligible_count=eligible_count+eligible;
        ids=find(eligible);X=reshape(permute(coeff(:,ids,:),[1 3 2]),n,[]);
        groups=repelem((1:numel(ids))',q);inner=folds.inner_fold{r,o};
        a=v371_fit_sparse_tuned(X,zeros(n,0),y,train,test,inner,groups,cfg);
        b=v371_fit_sparse_tuned(X,Z,y,train,test,inner,groups,cfg);
        ps(test,1)=ps(test,1)+a.probability;pc(test,1)=pc(test,1)+1;
        ps(test,2)=ps(test,2)+b.probability;pc(test,2)=pc(test,2)+1;
        gn=local_group_norm(b.model.beta,groups,numel(ids));sel=gn>cfg.selection_coefficient_tolerance;
        selection(ids(sel))=selection(ids(sel))+1;
        row=table(r,o,sum(train),sum(test),sum(eligible),sum(sel), ...
            v37_auc(y(test),a.probability),local_logloss(y(test),a.probability), ...
            v37_auc(y(test),b.probability),local_logloss(y(test),b.probability), ...
            'VariableNames',{'repeat','outer_fold','n_train','n_test','eligible_channels', ...
            'selected_sensor_channels','sensor_only_AUC','sensor_only_log_loss', ...
            'sensor_combined_AUC','sensor_combined_log_loss'});
        fold_rows=[fold_rows;row]; %#ok<AGROW>
        fprintf('sensor repeat %d fold %d: selected=%d combined AUC=%.3f\n',r,o,sum(sel),row.sensor_combined_AUC);
    end
end
probability=ps./max(pc,1);metrics=struct();
for i=1:2,metrics.(names(i))=v371_metrics(y,probability(:,i));end
result=struct('pipeline_version',cfg.pipeline_version,'model_names',names, ...
    'probability',probability,'metrics',metrics,'fold_results',fold_rows, ...
    'channel_label',sensor.channel_label,'eligible_count',eligible_count, ...
    'combined_selection_count',selection, ...
    'combined_selection_frequency',selection./max(eligible_count,1), ...
    'nuisance_names',{nuisance_names},'spectral_basis',B,'validation_participants_read',0);
end
function g=local_group_norm(beta,groups,n),g=zeros(n,1);for i=1:n,g(i)=norm(beta(groups==i));end;end
function l=local_logloss(y,p),p=min(max(p(:),1e-8),1-1e-8);y=y(:);l=-mean(y.*log(p)+(1-y).*log(1-p));end
