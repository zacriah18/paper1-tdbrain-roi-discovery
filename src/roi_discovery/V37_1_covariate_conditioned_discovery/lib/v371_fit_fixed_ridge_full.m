function fit = v371_fit_fixed_ridge_full(X,Z,y,fold_matrix,cfg)
%V371_FIT_FIXED_RIDGE_FULL Tune on locked discovery folds, then fit all 225.

X=double(X);Z=double(Z);y=double(y(:));
lambdas=double(cfg.peer_fixed_ridge_lambda(:));
score=zeros(numel(lambdas),1);count=zeros(numel(lambdas),1);
for r=1:size(fold_matrix,2)
    for o=1:max(fold_matrix(:,r))
        test=fold_matrix(:,r)==o;train=~test;
        [Xt,Xv,~,~]=local_prepare(X,find(train),find(test));
        [Zt,Zv,~,~]=local_prepare(Z,find(train),find(test));
        for l=1:numel(lambdas)
            model=local_fit(Xt,Zt,y(train),lambdas(l),cfg);
            p=local_sigmoid(Xv*model.beta+Zv*model.gamma+model.intercept);
            score(l)=score(l)+local_logloss(y(test),p);count(l)=count(l)+1;
        end
    end
end
score=score./max(count,1);[~,best]=min(score);
x_mean=mean(X,1,'omitnan');x_scale=std(X,0,1,'omitnan');
x_scale(~isfinite(x_scale)|x_scale<eps)=1;Xs=(X-x_mean)./x_scale;Xs(~isfinite(Xs))=0;
z_mean=mean(Z,1,'omitnan');z_scale=std(Z,0,1,'omitnan');
z_scale(~isfinite(z_scale)|z_scale<eps)=1;Zs=(Z-z_mean)./z_scale;Zs(~isfinite(Zs))=0;
model=local_fit(Xs,Zs,y,lambdas(best),cfg);
fit=struct('model',model,'lambda',lambdas(best),'cv_log_loss',score(best), ...
    'lambda_grid',lambdas,'cv_score',score,'neural_mean',x_mean, ...
    'neural_scale',x_scale,'nuisance_mean',z_mean,'nuisance_scale',z_scale);
end

function model=local_fit(X,Z,y,lambda,cfg)
n=numel(y);p=size(X,2);q=size(Z,2);A=[X Z ones(n,1)];
theta=zeros(p+q+1,1);theta(end)=local_logit(mean(y));
penalty=[lambda*ones(p,1);cfg.demographic_ridge*ones(q,1);0];
objective=local_objective(A,theta,y,penalty);
for iter=1:cfg.peer_fixed_max_iterations
    eta=A*theta;prob=local_sigmoid(eta);residual=prob-y;
    weight=max(prob.*(1-prob),1e-6);
    gradient=A'*residual/n+penalty.*theta;
    hessian=A'*(A.*weight)/n+diag(penalty)+eye(size(A,2))*1e-9;
    step=hessian\gradient;scale=1;accepted=false;
    for ls=1:25
        proposed=theta-scale*step;
        proposed_objective=local_objective(A,proposed,y,penalty);
        if isfinite(proposed_objective)&&proposed_objective<=objective
            accepted=true;break
        end
        scale=scale/2;
    end
    if ~accepted,break;end
    change=norm(proposed-theta)/max(1,norm(theta));
    theta=proposed;objective=proposed_objective;
    if change<cfg.peer_fixed_tolerance,break;end
end
model=struct('beta',theta(1:p),'gamma',theta(p+1:p+q), ...
    'intercept',theta(end),'lambda',lambda,'iterations',iter,'objective',objective);
end
function value=local_objective(A,theta,y,penalty)
eta=A*theta;value=mean(max(eta,0)-y.*eta+log1p(exp(-abs(eta))))+0.5*sum(penalty.*theta.^2);
end
function [Xt,Xv,mu,sigma]=local_prepare(X,train_idx,test_idx)
if isempty(X),Xt=zeros(numel(train_idx),0);Xv=zeros(numel(test_idx),0);mu=zeros(1,0);sigma=zeros(1,0);return;end
mu=mean(X(train_idx,:),1,'omitnan');sigma=std(X(train_idx,:),0,1,'omitnan');
sigma(~isfinite(sigma)|sigma<eps)=1;Xt=(X(train_idx,:)-mu)./sigma;Xv=(X(test_idx,:)-mu)./sigma;
Xt(~isfinite(Xt))=0;Xv(~isfinite(Xv))=0;
end
function p=local_sigmoid(x),p=1./(1+exp(-max(min(x,35),-35)));end
function x=local_logit(p),p=min(max(p,1e-6),1-1e-6);x=log(p/(1-p));end
function l=local_logloss(y,p),p=min(max(p(:),1e-8),1-1e-8);y=y(:);l=-mean(y.*log(p)+(1-y).*log(1-p));end
