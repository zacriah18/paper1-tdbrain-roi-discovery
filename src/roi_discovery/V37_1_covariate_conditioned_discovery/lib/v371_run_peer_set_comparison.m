function result=v371_run_peer_set_comparison(dataset,patches,cfg,y,folds,checkpoint_file)
%V371_RUN_PEER_SET_COMPARISON Discovery-only comparison of DCM-sized sets.
% Candidate construction is repeated inside every outer training split.

P=dataset.participants;y=double(y(:));n=numel(y);npatch=numel(dataset.patch_id);
if n~=cfg.expected_discovery_participants||any(string(P.assignment)~="discovery")
    error('V371:ValidationBoundary','Peer comparison permits only 225 discovery participants.');
end
if dataset.n_validation_participants_read~=0||cfg.validation_access_allowed
    error('V371:ValidationBoundary','Validation access must remain disabled.');
end
q=cfg.spectral_basis_count;B=v37_spectral_basis(numel(dataset.frequency_hz),q);
S=double(dataset.average_relative_log_spectrum);
coeff=reshape(reshape(S,n*npatch,[])*B,n,npatch,q);
[Z,nuisance_names]=v371_nuisance_matrix(P);
k_values=double(cfg.peer_set_sizes(:)');nK=numel(k_values);
R=cfg.outer_repeats;O=cfg.outer_folds;

state=local_initial_state(n,npatch,nK,R,O,cfg);
if nargin>=6&&~isempty(checkpoint_file)&&exist(checkpoint_file,'file')&&cfg.resume
    saved=load(checkpoint_file,'state');
    if ~strcmp(saved.state.pipeline_version,cfg.peer_pipeline_version)|| ...
            ~isequal(size(saved.state.done),[R O])
        error('V371:PeerCheckpoint','Peer checkpoint does not match this run.');
    end
    state=saved.state;
end

for r=1:R
    for o=1:O
        if state.done(r,o),continue;end
        test=folds.outer_fold(:,r)==o;train=~test;inner=folds.inner_fold{r,o};
        eligible=local_eligibility(dataset,coeff,train,cfg);
        patch_ids=find(eligible);X=local_patch_matrix(coeff,patch_ids);
        groups=repelem((1:numel(patch_ids))',q);

        combined=local_sparse_consensus(X,Z,y,train,test,inner,groups,cfg);
        neural=local_sparse_consensus(X,zeros(n,0),y,train,test,inner,groups,cfg);
        state.combined_frequency_sum(patch_ids)=state.combined_frequency_sum(patch_ids)+combined.selection_frequency;
        state.combined_norm_sum(patch_ids)=state.combined_norm_sum(patch_ids)+combined.mean_group_norm;
        state.neural_frequency_sum(patch_ids)=state.neural_frequency_sum(patch_ids)+neural.selection_frequency;
        state.neural_norm_sum(patch_ids)=state.neural_norm_sum(patch_ids)+neural.mean_group_norm;
        state.eligible_count=state.eligible_count+eligible;

        ranked=local_rank_ids(patch_ids,combined.selection_frequency,combined.mean_group_norm);
        [ranked_nonredundant,decisions]=local_prune(ranked,patches,cfg);
        if numel(ranked_nonredundant)<max(k_values)
            error('V371:PeerCandidates','Outer split has fewer than six nonredundant candidates.');
        end
        state.ranked_ids{r,o}=ranked;
        state.ranked_nonredundant_ids{r,o}=ranked_nonredundant;
        state.pruning_decisions{r,o}=decisions;

        [Zt,Zv]=v37_prepare_matrix(Z,train,test);
        dm=v37_ridge_logistic(Zt,y(train),cfg.demographic_ridge);
        pd=local_sigmoid([ones(sum(test),1),Zv]*dm.beta);
        state.demo_sum(test)=state.demo_sum(test)+pd;state.demo_count(test)=state.demo_count(test)+1;

        for kk=1:nK
            ids=ranked_nonredundant(1:k_values(kk));
            fixed=v371_fit_fixed_ridge_tuned(local_patch_matrix(coeff,ids),Z,y,train,test,inner,cfg);
            state.top_sum(test,kk)=state.top_sum(test,kk)+fixed.probability;
            state.top_count(test,kk)=state.top_count(test,kk)+1;
            state.top_selection_count(ids,kk)=state.top_selection_count(ids,kk)+1;
            m=v371_metrics(y(test),fixed.probability);
            row=table(r,o,k_values(kk),string(strjoin(string(ids),';')),fixed.lambda, ...
                m.AUC,m.log_loss,local_logloss(y(test),pd)-m.log_loss, ...
                'VariableNames',{'repeat','outer_fold','K','patch_ids','ridge_lambda', ...
                'AUC','log_loss','incremental_log_loss_vs_demographic'});
            state.fold_rows=[state.fold_rows;row]; %#ok<AGROW>
        end

        v37_ranked=local_rank_ids(patch_ids,neural.selection_frequency,neural.mean_group_norm);
        stable_mask=neural.selection_frequency>=cfg.peer_v37_inner_stability_threshold;
        v37_stable=v37_ranked(ismember(v37_ranked,patch_ids(stable_mask)));
        [v37_ids,~]=local_prune(v37_stable,patches,cfg);
        v37_ids=v37_ids(1:min(numel(v37_ids),cfg.dcm_family_max_nodes));
        if isempty(v37_ids)
            pv37=pd;v37_lambda=NaN;
        else
            fixed=v371_fit_fixed_ridge_tuned(local_patch_matrix(coeff,v37_ids),Z,y,train,test,inner,cfg);
            pv37=fixed.probability;v37_lambda=fixed.lambda;
        end
        state.v37_sum(test)=state.v37_sum(test)+pv37;state.v37_count(test)=state.v37_count(test)+1;

        active=patch_ids(combined.outer_group_norm>cfg.selection_coefficient_tolerance);
        active_norm=combined.outer_group_norm(combined.outer_group_norm>cfg.selection_coefficient_tolerance);
        active=local_rank_ids(active,ones(numel(active),1),active_norm);
        [active,~]=local_prune(active,patches,cfg);active=active(1:min(numel(active),cfg.dcm_family_max_nodes));
        if isempty(active)
            ppath=pd;path_lambda=NaN;
        else
            fixed=v371_fit_fixed_ridge_tuned(local_patch_matrix(coeff,active),Z,y,train,test,inner,cfg);
            ppath=fixed.probability;path_lambda=fixed.lambda;
        end
        state.path_sum(test)=state.path_sum(test)+ppath;state.path_count(test)=state.path_count(test)+1;
        state.rule_rows=[state.rule_rows;table(r,o,"v37_regenerated",numel(v37_ids), ...
            string(strjoin(string(v37_ids),';')),v37_lambda,local_logloss(y(test),pv37), ...
            local_logloss(y(test),pd)-local_logloss(y(test),pv37), ...
            'VariableNames',{'repeat','outer_fold','family','K','patch_ids','ridge_lambda','log_loss','incremental_log_loss_vs_demographic'})]; %#ok<AGROW>
        state.rule_rows=[state.rule_rows;table(r,o,"regularization_path",numel(active), ...
            string(strjoin(string(active),';')),path_lambda,local_logloss(y(test),ppath), ...
            local_logloss(y(test),pd)-local_logloss(y(test),ppath), ...
            'VariableNames',{'repeat','outer_fold','family','K','patch_ids','ridge_lambda','log_loss','incremental_log_loss_vs_demographic'})]; %#ok<AGROW>

        state.done(r,o)=true;
        fprintf('peer repeat %d fold %d: top1=%d top6=%s v37K=%d activeK=%d\n', ...
            r,o,ranked_nonredundant(1),strjoin(string(ranked_nonredundant(1:6)),','),numel(v37_ids),numel(active));
        local_save_checkpoint(checkpoint_file,state);
    end
end

[selection,performance]=local_choose_k(state,y,k_values,cfg);

for r=1:R
    for o=1:O
        if state.sensitivity_done(r,o),continue;end
        test=folds.outer_fold(:,r)==o;train=~test;inner=folds.inner_fold{r,o};
        selected=state.ranked_nonredundant_ids{r,o}(1:selection.chosen_k);
        [Zt,Zv]=v37_prepare_matrix(Z,train,test);
        dm=v37_ridge_logistic(Zt,y(train),cfg.demographic_ridge);
        pd=local_sigmoid([ones(sum(test),1),Zv]*dm.beta);
        if selection.chosen_k>1
            for d=1:selection.chosen_k
                ids=selected;ids(d)=[];
                fixed=v371_fit_fixed_ridge_tuned(local_patch_matrix(coeff,ids),Z,y,train,test,inner,cfg);
                state.sensitivity_rows=local_add_sensitivity(state.sensitivity_rows,r,o, ...
                    "leave_one_out",sprintf('drop_rank_%d',d),ids,fixed,pd,y(test));
            end
        end
        full_rank=state.ranked_ids{r,o};
        for d=1:selection.chosen_k
            alt=local_substitute(selected,d,full_rank,patches,cfg);
            if isempty(alt),continue;end
            fixed=v371_fit_fixed_ridge_tuned(local_patch_matrix(coeff,alt),Z,y,train,test,inner,cfg);
            state.sensitivity_rows=local_add_sensitivity(state.sensitivity_rows,r,o, ...
                "equivalence_substitution",sprintf('replace_rank_%d',d),alt,fixed,pd,y(test));
        end
        eligible=local_eligibility(dataset,coeff,train,cfg);eligible_ids=find(eligible);
        rng(cfg.peer_random_seed+10000*r+100*o,'twister');
        for b=1:cfg.peer_random_sets_per_fold
            ids=local_random_nonredundant(eligible_ids,selection.chosen_k,patches,cfg);
            fixed=v371_fit_fixed_ridge_tuned(local_patch_matrix(coeff,ids),Z,y,train,test,inner,cfg);
            state.sensitivity_rows=local_add_sensitivity(state.sensitivity_rows,r,o, ...
                "random_nonredundant",sprintf('random_%02d',b),ids,fixed,pd,y(test));
        end
        state.sensitivity_done(r,o)=true;
        fprintf('peer sensitivity repeat %d fold %d: K=%d complete\n',r,o,selection.chosen_k);
        local_save_checkpoint(checkpoint_file,state);
    end
end

frequency=state.combined_frequency_sum./max(state.eligible_count,1);
mean_norm=state.combined_norm_sum./max(state.eligible_count,1);
ranked=local_rank_ids(dataset.patch_id,frequency,mean_norm);
[final_ranked,final_decisions]=local_prune(ranked,patches,cfg);
final_ids=final_ranked(1:selection.chosen_k);
Xfinal=local_patch_matrix(coeff,final_ids);
frozen_model=v371_fit_fixed_ridge_full(Xfinal,Z,y,folds.outer_fold(:,1:R),cfg);
Zs=(Z-frozen_model.nuisance_mean)./frozen_model.nuisance_scale;Zs(~isfinite(Zs))=0;
frozen_demographic_model=v37_ridge_logistic(Zs,y,cfg.demographic_ridge);
identifiability=local_identifiability(final_ids,patches,cfg);

dcm_ids=zeros(0,1);dcm_identifiability=struct();dcm_frozen_model=struct();
if isfinite(selection.dcm_candidate_k)
    dcm_ids=final_ranked(1:selection.dcm_candidate_k);
    dcm_identifiability=local_identifiability(dcm_ids,patches,cfg);
    dcm_frozen_model=v371_fit_fixed_ridge_full(local_patch_matrix(coeff,dcm_ids),Z,y, ...
        folds.outer_fold(:,1:R),cfg);
end

result=struct('pipeline_version',cfg.peer_pipeline_version,'k_values',k_values, ...
    'performance',performance,'selection',selection,'fold_rows',state.fold_rows, ...
    'rule_rows',state.rule_rows,'sensitivity_rows',state.sensitivity_rows, ...
    'patch_id',dataset.patch_id,'combined_consensus_frequency',frequency, ...
    'combined_mean_group_norm',mean_norm,'top_selection_count',state.top_selection_count, ...
    'final_ranked_patch_ids',final_ranked,'final_pruning_decisions',final_decisions, ...
    'final_patch_ids',final_ids,'dcm_candidate_patch_ids',dcm_ids, ...
    'frozen_model',frozen_model,'frozen_demographic_model',frozen_demographic_model, ...
    'dcm_frozen_model',dcm_frozen_model,'spectral_basis',B,'nuisance_names',{nuisance_names}, ...
    'identifiability',identifiability,'dcm_identifiability',dcm_identifiability, ...
    'validation_freeze_ready',selection.incremental_log_loss>0&&identifiability.structural_pass, ...
    'validation_participants_read',0,'validation_access_allowed',false);
end

function state=local_initial_state(n,npatch,nK,R,O,cfg)
state=struct('pipeline_version',cfg.peer_pipeline_version,'done',false(R,O), ...
    'sensitivity_done',false(R,O),'demo_sum',zeros(n,1),'demo_count',zeros(n,1), ...
    'top_sum',zeros(n,nK),'top_count',zeros(n,nK),'v37_sum',zeros(n,1), ...
    'v37_count',zeros(n,1),'path_sum',zeros(n,1),'path_count',zeros(n,1), ...
    'combined_frequency_sum',zeros(npatch,1),'combined_norm_sum',zeros(npatch,1), ...
    'neural_frequency_sum',zeros(npatch,1),'neural_norm_sum',zeros(npatch,1), ...
    'eligible_count',zeros(npatch,1),'top_selection_count',zeros(npatch,nK), ...
    'ranked_ids',{cell(R,O)},'ranked_nonredundant_ids',{cell(R,O)}, ...
    'pruning_decisions',{cell(R,O)},'fold_rows',table(),'rule_rows',table(), ...
    'sensitivity_rows',table());
end

function consensus=local_sparse_consensus(X,Z,y,train,test,inner_fold,groups,cfg)
fit=v371_fit_sparse_tuned(X,Z,y,train,test,inner_fold,groups,cfg);
train_idx=find(train);ng=max(groups);inner_norm=zeros(ng,cfg.inner_folds);
for inner=1:cfg.inner_folds
    iv=inner_fold==inner;it=~iv;itr=train_idx(it);
    [Xi,~]=v37_prepare_matrix(X,itr,itr);
    if isempty(Z),Zi=zeros(numel(itr),0);else,[Zi,~]=v37_prepare_matrix(Z,itr,itr);end
    base=local_lambda_base(Xi,Zi,y(itr),groups,cfg);
    model=v371_sparse_group_logistic(Xi,Zi,y(itr),groups, ...
        fit.lambda_fraction*base,fit.alpha,cfg,local_solver_step(Xi,Zi));
    inner_norm(:,inner)=local_group_norm(model.beta,groups,ng);
end
consensus=struct('selection_frequency',mean(inner_norm>cfg.selection_coefficient_tolerance,2), ...
    'mean_group_norm',mean(inner_norm,2),'outer_group_norm', ...
    local_group_norm(fit.model.beta,groups,ng),'alpha',fit.alpha, ...
    'lambda_fraction',fit.lambda_fraction,'lambda',fit.lambda);
end

function ids=local_rank_ids(ids,frequency,magnitude)
ids=double(ids(:));frequency=double(frequency(:));magnitude=double(magnitude(:));
if isempty(ids),return;end
T=table(ids,frequency,magnitude,'VariableNames',{'id','frequency','magnitude'});
T=sortrows(T,{'frequency','magnitude','id'},{'descend','descend','ascend'});ids=T.id;
end

function [kept,decisions]=local_prune(ranked,patches,cfg)
ranked=double(ranked(:));kept=zeros(0,1);patch=zeros(0,1);representative=zeros(0,1);reason=strings(0,1);
xyz=[patches.patch_table.x,patches.patch_table.y,patches.patch_table.z];
for i=1:numel(ranked)
    p=ranked(i);conflict=0;why="retained";
    for j=1:numel(kept)
        q=kept(j);distance=norm(xyz(p,:)-xyz(q,:));
        correlation=double(patches.rms_canonical_correlation(p,q));
        if distance<cfg.redundancy_coordinate_distance_mm
            conflict=q;why="coordinate_distance";break
        elseif correlation>=cfg.redundancy_subspace_rms_correlation
            conflict=q;why="lead_field_equivalence";break
        end
    end
    patch(end+1,1)=p;representative(end+1,1)=max(conflict,p*(conflict==0));reason(end+1,1)=why; %#ok<AGROW>
    if conflict==0,kept(end+1,1)=p;end %#ok<AGROW>
end
decisions=table(patch,representative,reason,'VariableNames',{'patch_id','representative_patch_id','decision'});
end

function [selection,performance]=local_choose_k(state,y,k_values,cfg)
pd=state.demo_sum./max(state.demo_count,1);demo=v371_metrics(y,pd);nK=numel(k_values);
rows=table();loss=zeros(numel(y),nK);mean_loss=zeros(nK,1);
for kk=1:nK
    p=state.top_sum(:,kk)./max(state.top_count(:,kk),1);m=v371_metrics(y,p);
    loss(:,kk)=local_individual_loss(y,p);mean_loss(kk)=mean(loss(:,kk));
    rows=[rows;table(k_values(kk),m.AUC,m.log_loss,m.Brier,m.balanced_accuracy, ...
        m.sensitivity,m.specificity,m.calibration_intercept,m.calibration_slope, ...
        demo.log_loss-m.log_loss,m.AUC-demo.AUC, ...
        'VariableNames',{'K','AUC','log_loss','Brier','balanced_accuracy','sensitivity', ...
        'specificity','calibration_intercept','calibration_slope', ...
        'incremental_log_loss','incremental_AUC'})]; %#ok<AGROW>
end
[best_loss,best_index]=min(mean_loss);
best_se=local_bootstrap_se(loss(:,best_index),y,cfg.peer_bootstrap_count,cfg.peer_random_seed+17);
eligible=find(mean_loss<=best_loss+best_se+eps);chosen_index=eligible(1);
dcm_index=eligible(find(k_values(eligible)>=cfg.dcm_family_min_nodes,1,'first'));
if isempty(dcm_index),dcm_k=NaN;else,dcm_k=k_values(dcm_index);end
delta=local_individual_loss(y,pd)-loss(:,chosen_index);
[delta_low,delta_high]=local_bootstrap_ci(delta,y,cfg.peer_bootstrap_count,cfg.peer_random_seed+19);
selection=struct('best_k',k_values(best_index),'chosen_k',k_values(chosen_index), ...
    'dcm_candidate_k',dcm_k,'best_mean_log_loss',best_loss, ...
    'best_participant_bootstrap_se',best_se,'one_se_threshold',best_loss+best_se, ...
    'incremental_log_loss',mean(delta),'incremental_log_loss_ci',[delta_low delta_high]);
performance=struct('demographic',demo,'top_k',rows, ...
    'v37_regenerated',v371_metrics(y,state.v37_sum./max(state.v37_count,1)), ...
    'regularization_path',v371_metrics(y,state.path_sum./max(state.path_count,1)));
end

function rows=local_add_sensitivity(rows,r,o,family,variant,ids,fit,pd,ytest)
m=v371_metrics(ytest,fit.probability);
row=table(r,o,family,string(variant),numel(ids),string(strjoin(string(ids),';')), ...
    fit.lambda,m.AUC,m.log_loss,local_logloss(ytest,pd)-m.log_loss, ...
    'VariableNames',{'repeat','outer_fold','family','variant','K','patch_ids', ...
    'ridge_lambda','AUC','log_loss','incremental_log_loss_vs_demographic'});
rows=[rows;row];
end

function alt=local_substitute(selected,index,full_rank,patches,cfg)
target=selected(index);others=selected;others(index)=[];alt=[];
xyz=[patches.patch_table.x,patches.patch_table.y,patches.patch_table.z];
for candidate=full_rank(:)'
    if ismember(candidate,selected),continue;end
    equivalent=norm(xyz(candidate,:)-xyz(target,:))<cfg.redundancy_coordinate_distance_mm|| ...
        double(patches.rms_canonical_correlation(candidate,target))>=cfg.redundancy_subspace_rms_correlation;
    if ~equivalent,continue;end
    conflict=false;
    for q=others(:)'
        if norm(xyz(candidate,:)-xyz(q,:))<cfg.redundancy_coordinate_distance_mm|| ...
                double(patches.rms_canonical_correlation(candidate,q))>=cfg.redundancy_subspace_rms_correlation
            conflict=true;break
        end
    end
    if ~conflict,alt=selected;alt(index)=candidate;return;end
end
end

function ids=local_random_nonredundant(pool,K,patches,cfg)
for attempt=1:100
    order=pool(randperm(numel(pool)));[candidate,~]=local_prune(order,patches,cfg);
    if numel(candidate)>=K,ids=candidate(1:K);return;end
end
error('V371:PeerRandom','Unable to sample a nonredundant random set.');
end

function audit=local_identifiability(ids,patches,cfg)
ids=double(ids(:));K=numel(ids);xyz=[patches.patch_table.x,patches.patch_table.y,patches.patch_table.z];
distance=nan(K);correlation=nan(K);
for i=1:K
    for j=1:K
        distance(i,j)=norm(xyz(ids(i),:)-xyz(ids(j),:));
        correlation(i,j)=double(patches.rms_canonical_correlation(ids(i),ids(j)));
    end
end
pairwise_pass=all(distance(triu(true(K),1))>=cfg.redundancy_coordinate_distance_mm)&& ...
    all(correlation(triu(true(K),1))<cfg.redundancy_subspace_rms_correlation);
D=spm_eeg_load(char(patches.template_source_file));Ic=D.indchantype('EEG','GOOD');
[L,~]=spm_eeg_lgainmat(D,[],D.chanlabels(Ic));L=full(double(L));
[sensor_modes,~,~]=svd(L,'econ');sensor_modes=sensor_modes(:,1:min(cfg.peer_joint_channel_modes,size(sensor_modes,2)));
dominant=zeros(size(sensor_modes,2),K);visibility=zeros(K,1);block=zeros(size(sensor_modes,2),0);
for i=1:K
    ip=find(patches.membership(:,ids(i)));U=spm_svd(L(:,ip)',0);U=U(:,1:cfg.regional_spatial_modes);
    G=full(L(:,ip)*U);[Ug,~,~]=svd(G,'econ');
    projected=sensor_modes'*G;block=[block projected]; %#ok<AGROW>
    dominant(:,i)=sensor_modes'*Ug(:,1);dominant(:,i)=dominant(:,i)/max(norm(dominant(:,i)),eps);
    visibility(i)=norm(projected,'fro')/max(norm(G,'fro'),eps);
end
joint_rank=rank(dominant);s=svd(dominant);p=(s.^2)/max(sum(s.^2),eps);
effective_rank=exp(-sum(p.*log(max(p,eps))));
audit=struct('patch_ids',ids,'pairwise_distance_mm',distance, ...
    'pairwise_rms_canonical_correlation',correlation,'pairwise_pass',pairwise_pass, ...
    'channel_modes',size(sensor_modes,2),'dominant_pattern_joint_rank',joint_rank, ...
    'dominant_pattern_effective_rank',effective_rank,'regional_block_rank',rank(block), ...
    'sensor_mode_visibility',visibility,'structural_pass',pairwise_pass&&joint_rank>=K, ...
    'sensor_space_CSD_sensitivity_pending',true);
end

function eligible=local_eligibility(dataset,coeff,train,cfg)
coverage=mean(all(isfinite(coeff(train,:,:)),3),1);coverage=coverage(:);
reliability=median(double(dataset.technical.split_half_spectral_correlation(train,:)),1,'omitnan');reliability=reliability(:);
rankv=median(double(dataset.technical.regional_mode_rank(train,:)),1,'omitnan');rankv=rankv(:);
fn=median(double(dataset.technical.filter_norm(train,:)),1,'omitnan');fn=fn(:);
eligible=coverage>=cfg.minimum_participant_coverage& ...
    reliability>=cfg.minimum_median_split_half_spectral_correlation& ...
    rankv>=cfg.minimum_median_regional_mode_rank&fn>=cfg.minimum_filter_norm;
end
function X=local_patch_matrix(coeff,ids)
n=size(coeff,1);q=size(coeff,3);X=reshape(permute(coeff(:,ids,:),[1 3 2]),n,q*numel(ids));
end
function g=local_group_norm(beta,groups,n),g=zeros(n,1);for i=1:n,g(i)=norm(beta(groups==i));end;end
function base=local_lambda_base(X,Z,y,groups,cfg)
if isempty(Z),p0=ones(numel(y),1)*mean(y);else,dm=v37_ridge_logistic(Z,y,cfg.demographic_ridge);p0=local_sigmoid([ones(size(Z,1),1),Z]*dm.beta);end
g=X'*(p0-y(:))/size(X,1);base=max(abs(g));
for id=unique(groups(:))',idx=groups==id;base=max(base,norm(g(idx))/sqrt(sum(idx)));end
base=max(base,1e-6);
end
function step=local_solver_step(X,Z)
n=size(X,1);W=[X Z ones(n,1)];v=ones(size(W,2),1);v=v/norm(v);
for i=1:25,v=W'*(W*v);nv=norm(v);if nv<=eps,step=1e8;return;end;v=v/nv;end
sn=norm(W*v);step=1/(0.25*(sn^2/n)+1e-8);
end
function se=local_bootstrap_se(values,y,B,seed)
rng(seed,'twister');boot=zeros(B,1);a=find(y==0);b=find(y==1);
for i=1:B,idx=[a(randi(numel(a),numel(a),1));b(randi(numel(b),numel(b),1))];boot(i)=mean(values(idx));end
se=std(boot,0);
end
function [lo,hi]=local_bootstrap_ci(values,y,B,seed)
rng(seed,'twister');boot=zeros(B,1);a=find(y==0);b=find(y==1);
for i=1:B,idx=[a(randi(numel(a),numel(a),1));b(randi(numel(b),numel(b),1))];boot(i)=mean(values(idx));end
ci=prctile(boot,[2.5 97.5]);lo=ci(1);hi=ci(2);
end
function loss=local_individual_loss(y,p),p=min(max(p(:),1e-8),1-1e-8);loss=-(y(:).*log(p)+(1-y(:)).*log(1-p));end
function p=local_sigmoid(x),p=1./(1+exp(-max(min(x,35),-35)));end
function l=local_logloss(y,p),l=mean(local_individual_loss(y,p));end
function local_save_checkpoint(file,state)
if nargin<1||isempty(file),return;end
folder=fileparts(file);if ~exist(folder,'dir'),mkdir(folder);end
save(file,'state','-v7.3');
end
