function result = v37_run_nested_cv(dataset, cfg, y)
%V37_RUN_NESTED_CV Repeated nested neural-only supervised ROI discovery.
participants = dataset.participants;
y = double(y(:));
n = numel(y); npatch = numel(dataset.patch_id);
q = cfg.spectral_basis_count;
B = v37_spectral_basis(numel(dataset.frequency_hz), q);
S = double(dataset.average_relative_log_spectrum);
coeff = reshape(reshape(S,n*npatch,[]) * B, n, npatch, q);

oof_neural_sum = zeros(n,1); oof_demo_sum = zeros(n,1); oof_count = zeros(n,1);
selection_count = zeros(npatch,1); eligibility_count = zeros(npatch,1);
coefficient_magnitude_sum = zeros(npatch,1);
fold_rows = table();

for repeat = 1:cfg.outer_repeats
    fold = v37_make_folds(y,participants.sex,participants.age_band, ...
        cfg.outer_folds,cfg.random_seed+1000*repeat);
    for outer = 1:cfg.outer_folds
        test = fold == outer; train = ~test;
        if numel(unique(y(train)))<2 || numel(unique(y(test)))<2, continue; end
        eligible = local_eligibility(dataset,coeff,train,cfg);
        eligibility_count = eligibility_count + eligible;
        patch_ids = find(eligible);
        if isempty(patch_ids), error('V37:Eligibility','No eligible patches in outer fold.'); end
        X = reshape(permute(coeff(:,patch_ids,:),[1 3 2]),n,[]);
        groups = repelem((1:numel(patch_ids))',q);

        % Inner tuning repeats imputation and scaling within every inner fold.
        inner_fold = v37_make_folds(y(train),participants.sex(train), ...
            participants.age_band(train),cfg.inner_folds, ...
            cfg.random_seed+1000*repeat+outer);
        train_idx = find(train);
        score = inf(numel(cfg.sparse_group_alpha),numel(cfg.lambda_fraction));
        for a = 1:numel(cfg.sparse_group_alpha)
            for l = 1:numel(cfg.lambda_fraction)
                losses = nan(cfg.inner_folds,1);
                for inner = 1:cfg.inner_folds
                    iv = inner_fold == inner; it = ~iv;
                    if numel(unique(y(train_idx(it))))<2 || numel(unique(y(train_idx(iv))))<2
                        continue
                    end
                    [Xi,Xv] = v37_prepare_matrix(X,train_idx(it),train_idx(iv));
                    yi = y(train_idx(it)); yv = y(train_idx(iv));
                    base = local_lambda_base(Xi,yi,groups);
                    lambda = cfg.lambda_fraction(l)*base;
                    m = v37_sparse_group_logistic(Xi,yi,groups,lambda, ...
                        cfg.sparse_group_alpha(a),cfg);
                    p = local_sigmoid(Xv*m.beta+m.intercept);
                    losses(inner) = local_logloss(yv,p);
                end
                score(a,l) = mean(losses,'omitnan');
            end
        end
        [~,best] = min(score(:)); [a,l] = ind2sub(size(score),best);
        [Xt,Xv] = v37_prepare_matrix(X,train,test);
        base = local_lambda_base(Xt,y(train),groups);
        lambda = cfg.lambda_fraction(l)*base;
        model = v37_sparse_group_logistic(Xt,y(train),groups,lambda, ...
            cfg.sparse_group_alpha(a),cfg);
        pred = local_sigmoid(Xv*model.beta+model.intercept);
        oof_neural_sum(test) = oof_neural_sum(test)+pred;
        oof_count(test) = oof_count(test)+1;

        beta_group = zeros(numel(patch_ids),1);
        for g = 1:numel(patch_ids)
            beta_group(g) = norm(model.beta(groups==g));
        end
        selected = beta_group > cfg.selection_coefficient_tolerance;
        selection_count(patch_ids(selected)) = selection_count(patch_ids(selected))+1;
        coefficient_magnitude_sum(patch_ids) = ...
            coefficient_magnitude_sum(patch_ids)+beta_group;

        % Age/sex benchmark is evaluated separately and never enters X.
        Ddemo = local_demographics(participants);
        [Dt,Dv] = v37_prepare_matrix(Ddemo,train,test);
        dm = v37_ridge_logistic(Dt,y(train),1);
        dp = local_sigmoid([ones(sum(test),1),Dv]*dm.beta);
        oof_demo_sum(test) = oof_demo_sum(test)+dp;

        row = table(repeat,outer,sum(train),sum(test),sum(eligible), ...
            cfg.sparse_group_alpha(a),cfg.lambda_fraction(l),lambda, ...
            sum(selected),v37_auc(y(test),pred),local_logloss(y(test),pred), ...
            'VariableNames',{'repeat','outer_fold','n_train','n_test', ...
            'n_eligible_patches','alpha','lambda_fraction','lambda', ...
            'n_selected_patches','test_AUC','test_log_loss'});
        fold_rows = [fold_rows;row]; %#ok<AGROW>
        fprintf('repeat %d fold %d: eligible=%d selected=%d AUC=%.3f\n', ...
            repeat,outer,sum(eligible),sum(selected),row.test_AUC);
    end
end

oof_neural = oof_neural_sum ./ max(oof_count,1);
oof_demographic = oof_demo_sum ./ max(oof_count,1);
denominator = max(eligibility_count,1);
result = struct();
result.y = y;
result.oof_neural_probability = oof_neural;
result.oof_demographic_probability = oof_demographic;
result.oof_prediction_count = oof_count;
result.neural_AUC = v37_auc(y,oof_neural);
result.demographic_AUC = v37_auc(y,oof_demographic);
result.neural_log_loss = local_logloss(y,oof_neural);
result.demographic_log_loss = local_logloss(y,oof_demographic);
result.patch_id = dataset.patch_id;
result.selection_count = selection_count;
result.eligibility_count = eligibility_count;
result.selection_frequency_when_eligible = selection_count./denominator;
result.mean_coefficient_magnitude_when_eligible = ...
    coefficient_magnitude_sum./denominator;
result.fold_results = fold_rows;
result.spectral_basis = B;
result.feature_count_per_patch = q;
result.neural_feature_rule = ...
    "six fixed cosine coefficients of the participant-relative 4-45 Hz regional spectrum";
result.age_sex_used_for_neural_selection = false;
end

function eligible = local_eligibility(dataset,coeff,train,cfg)
coverage = mean(all(isfinite(coeff(train,:,:)),3),1);
coverage = coverage(:);
reliability = median(double(dataset.technical.split_half_spectral_correlation(train,:)),1,'omitnan');
reliability = reliability(:);
mode_rank = median(double(dataset.technical.regional_mode_rank(train,:)),1,'omitnan');
mode_rank = mode_rank(:);
filter_norm = median(double(dataset.technical.filter_norm(train,:)),1,'omitnan');
filter_norm = filter_norm(:);
eligible = coverage >= cfg.minimum_participant_coverage & ...
    reliability >= cfg.minimum_median_split_half_spectral_correlation & ...
    mode_rank >= cfg.minimum_median_regional_mode_rank & ...
    filter_norm >= cfg.minimum_filter_norm;
end

function base = local_lambda_base(X,y,groups)
g = X'*(0.5-double(y(:)))/size(X,1);
base = max(abs(g));
for id = unique(groups(:))'
    idx = groups==id;
    base = max(base,norm(g(idx))/sqrt(sum(idx)));
end
base = max(base,1e-6);
end

function X = local_demographics(P)
age = double(P.age); sex = upper(string(P.sex));
female = double(ismember(sex,["F","FEMALE"]));
X = [age(:),female(:)];
end
function p = local_sigmoid(x), p=1./(1+exp(-max(min(x,35),-35))); end
function l = local_logloss(y,p)
p=min(max(double(p(:)),1e-8),1-1e-8); y=double(y(:));
l=-mean(y.*log(p)+(1-y).*log(1-p));
end
