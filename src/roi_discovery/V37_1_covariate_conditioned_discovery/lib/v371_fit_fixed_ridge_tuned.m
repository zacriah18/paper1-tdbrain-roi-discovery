function fit = v371_fit_fixed_ridge_tuned(X,Z,y,train,test,inner_fold,cfg)
%V371_FIT_FIXED_RIDGE_TUNED Evaluate a prespecified neural feature set.
% Neural coefficients receive an L2 penalty. Nuisance coefficients and the
% intercept are retained with only the frozen numerical stabilizer.

y=double(y(:)); train=logical(train(:)); test=logical(test(:));
train_idx=find(train); lambdas=double(cfg.peer_fixed_ridge_lambda(:));
score=inf(numel(lambdas),1);
for l=1:numel(lambdas)
    losses=nan(cfg.inner_folds,1);
    for inner=1:cfg.inner_folds
        iv=inner_fold==inner; it=~iv;
        itr=train_idx(it); iva=train_idx(iv);
        if numel(unique(y(itr)))<2||numel(unique(y(iva)))<2,continue;end
        [Xi,Xv,~,~]=local_prepare(X,itr,iva);
        [Zi,Zv,~,~]=local_prepare(Z,itr,iva);
        model=local_fit(Xi,Zi,y(itr),lambdas(l),cfg);
        p=local_sigmoid(Xv*model.beta+Zv*model.gamma+model.intercept);
        losses(inner)=local_logloss(y(iva),p);
    end
    score(l)=mean(losses,'omitnan');
end
[~,best]=min(score);
[Xt,Xv,x_mean,x_scale]=local_prepare(X,find(train),find(test));
[Zt,Zv,z_mean,z_scale]=local_prepare(Z,find(train),find(test));
model=local_fit(Xt,Zt,y(train),lambdas(best),cfg);
fit=struct('model',model, ...
    'probability',local_sigmoid(Xv*model.beta+Zv*model.gamma+model.intercept), ...
    'lambda',lambdas(best),'inner_log_loss',score(best), ...
    'lambda_grid',lambdas,'inner_score',score, ...
    'neural_mean',x_mean,'neural_scale',x_scale, ...
    'nuisance_mean',z_mean,'nuisance_scale',z_scale);
end

function model=local_fit(X,Z,y,lambda,cfg)
n=numel(y); p=size(X,2); q=size(Z,2); A=[X Z ones(n,1)];
theta=zeros(p+q+1,1); theta(end)=local_logit(mean(y));
penalty=[lambda*ones(p,1);cfg.demographic_ridge*ones(q,1);0];
objective=local_objective(A,theta,y,penalty);
for iter=1:cfg.peer_fixed_max_iterations
    eta=A*theta; prob=local_sigmoid(eta); residual=prob-y;
    weight=max(prob.*(1-prob),1e-6);
    gradient=A'*residual/n+penalty.*theta;
    hessian=A'*(A.*weight)/n+diag(penalty)+eye(size(A,2))*1e-9;
    step=hessian\gradient;
    scale=1;
    accepted=false;
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
    'intercept',theta(end),'lambda',lambda,'iterations',iter, ...
    'objective',objective);
end

function value=local_objective(A,theta,y,penalty)
eta=A*theta;
value=mean(max(eta,0)-y.*eta+log1p(exp(-abs(eta))))+ ...
    0.5*sum(penalty.*theta.^2);
end

function [Xt,Xv,mu,sigma]=local_prepare(X,train_idx,test_idx)
if isempty(X)
    Xt=zeros(numel(train_idx),0);Xv=zeros(numel(test_idx),0);
    mu=zeros(1,0);sigma=zeros(1,0);return
end
X=double(X);mu=mean(X(train_idx,:),1,'omitnan');
sigma=std(X(train_idx,:),0,1,'omitnan');sigma(~isfinite(sigma)|sigma<eps)=1;
Xt=(X(train_idx,:)-mu)./sigma;Xv=(X(test_idx,:)-mu)./sigma;
Xt(~isfinite(Xt))=0;Xv(~isfinite(Xv))=0;
end

function p=local_sigmoid(x),p=1./(1+exp(-max(min(x,35),-35)));end
function x=local_logit(p),p=min(max(p,1e-6),1-1e-6);x=log(p/(1-p));end
function l=local_logloss(y,p)
p=min(max(p(:),1e-8),1-1e-8);y=y(:);
l=-mean(y.*log(p)+(1-y).*log(1-p));
end
