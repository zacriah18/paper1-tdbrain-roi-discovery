function fit = v371_fit_sparse_tuned(X,Z,y,train,test,inner_fold,groups,cfg)
%V371_FIT_SPARSE_TUNED Inner-tuned sparse-group fit on one outer split.
train_idx=find(train); score=inf(numel(cfg.sparse_group_alpha),numel(cfg.lambda_fraction));
cache=cell(cfg.inner_folds,1);
for inner=1:cfg.inner_folds
    iv=inner_fold==inner;it=~iv;itr=train_idx(it);iva=train_idx(iv);
    if numel(unique(y(itr)))<2||numel(unique(y(iva)))<2,continue;end
    [Xi,Xv]=v37_prepare_matrix(X,itr,iva);
    if isempty(Z),Zi=zeros(sum(it),0);Zv=zeros(sum(iv),0);else,[Zi,Zv]=v37_prepare_matrix(Z,itr,iva);end
    cache{inner}=struct('Xi',Xi,'Xv',Xv,'Zi',Zi,'Zv',Zv,'yi',y(itr), ...
        'yv',y(iva),'base',local_lambda_base(Xi,Zi,y(itr),groups,cfg), ...
        'step',local_solver_step(Xi,Zi));
end
for a=1:numel(cfg.sparse_group_alpha)
    for l=1:numel(cfg.lambda_fraction)
        losses=nan(cfg.inner_folds,1);
        for inner=1:cfg.inner_folds
            if isempty(cache{inner}),continue;end;c=cache{inner};
            lambda=cfg.lambda_fraction(l)*c.base;
            m=v371_sparse_group_logistic(c.Xi,c.Zi,c.yi,groups,lambda, ...
                cfg.sparse_group_alpha(a),cfg,c.step);
            p=local_sigmoid(c.Xv*m.beta+c.Zv*m.gamma+m.intercept);
            losses(inner)=local_logloss(c.yv,p);
        end
        score(a,l)=mean(losses,'omitnan');
    end
end
[~,best]=min(score(:));[a,l]=ind2sub(size(score),best);
[Xt,Xv]=v37_prepare_matrix(X,train,test);
if isempty(Z),Zt=zeros(sum(train),0);Zv=zeros(sum(test),0);else,[Zt,Zv]=v37_prepare_matrix(Z,train,test);end
base=local_lambda_base(Xt,Zt,y(train),groups,cfg);lambda=cfg.lambda_fraction(l)*base;
model=v371_sparse_group_logistic(Xt,Zt,y(train),groups,lambda, ...
    cfg.sparse_group_alpha(a),cfg,local_solver_step(Xt,Zt));
fit=struct('model',model,'probability',local_sigmoid(Xv*model.beta+Zv*model.gamma+model.intercept), ...
    'alpha',cfg.sparse_group_alpha(a),'lambda_fraction',cfg.lambda_fraction(l), ...
    'lambda',lambda,'inner_log_loss',score(a,l));
end
function base=local_lambda_base(X,Z,y,groups,cfg)
if isempty(Z)
    p0=ones(numel(y),1)*mean(y);
else
    dm=v37_ridge_logistic(Z,y,cfg.demographic_ridge);
    p0=local_sigmoid([ones(size(Z,1),1),Z]*dm.beta);
end
g=X'*(p0-y(:))/size(X,1);base=max(abs(g));
for id=unique(groups(:))',idx=groups==id;base=max(base,norm(g(idx))/sqrt(sum(idx)));end
base=max(base,1e-6);
end
function p=local_sigmoid(x),p=1./(1+exp(-max(min(x,35),-35)));end
function l=local_logloss(y,p),p=min(max(p(:),1e-8),1-1e-8);y=y(:);l=-mean(y.*log(p)+(1-y).*log(1-p));end
function step=local_solver_step(X,Z)
n=size(X,1);W=[X Z ones(n,1)];sn=local_spectral_norm(W);
step=1/(0.25*(sn^2/n)+1e-8);
end
function s=local_spectral_norm(X)
if isempty(X),s=0;return;end
v=ones(size(X,2),1);v=v/norm(v);
for i=1:25
    v=X'*(X*v);nv=norm(v);if nv<=eps,s=0;return;end;v=v/nv;
end
s=norm(X*v);
end
