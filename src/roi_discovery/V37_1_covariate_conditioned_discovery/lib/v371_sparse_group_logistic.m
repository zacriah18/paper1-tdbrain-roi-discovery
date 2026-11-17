function model = v371_sparse_group_logistic(X,Z,y,groups,lambda,alpha,cfg,step)
%V371_SPARSE_GROUP_LOGISTIC Logistic model with unpenalized nuisance terms.
X=double(X); Z=double(Z); y=double(y(:)); groups=double(groups(:));
[n,p]=size(X); q=size(Z,2);
beta=zeros(p,1); gamma=zeros(q,1); intercept=local_logit(mean(y));
zb=beta; zg=gamma; zi=intercept; t=1;
if nargin<8||isempty(step)
    W=[X Z ones(n,1)];sn=local_spectral_norm(W);
    L=0.25*(sn^2/n)+1e-8;step=1/L;
end
ng=max(groups);group_size=accumarray(groups,1,[ng 1]);
group_threshold=step*lambda*(1-alpha)*sqrt(group_size);
for iter=1:cfg.optim_max_iterations
    eta=X*zb+Z*zg+zi; prob=local_sigmoid(eta); residual=prob-y;
    gb=X'*residual/n; gg=Z'*residual/n; gi=mean(residual);
    bnew=zb-step*gb;
    bnew=sign(bnew).*max(abs(bnew)-step*lambda*alpha,0);
    if alpha<1
        group_norm=sqrt(accumarray(groups,bnew.^2,[ng 1],@sum,0));
        group_scale=max(1-group_threshold./max(group_norm,eps),0);
        bnew=bnew.*group_scale(groups);
    end
    gnew=zg-step*gg; inew=zi-step*gi;
    tnew=(1+sqrt(1+4*t^2))/2;
    zb=bnew+((t-1)/tnew)*(bnew-beta);
    zg=gnew+((t-1)/tnew)*(gnew-gamma);
    zi=inew+((t-1)/tnew)*(inew-intercept);
    change=norm([bnew-beta;gnew-gamma;inew-intercept])/ ...
        max(1,norm([beta;gamma;intercept]));
    beta=bnew; gamma=gnew; intercept=inew; t=tnew;
    if change<cfg.optim_tolerance,break;end
end
model=struct('beta',beta,'gamma',gamma,'intercept',intercept, ...
    'iterations',iter,'lambda',lambda,'alpha',alpha,'step',step);
end
function s=local_spectral_norm(X)
if isempty(X),s=0;return;end
v=ones(size(X,2),1);v=v/norm(v);
for i=1:25
    v=X'*(X*v);nv=norm(v);if nv<=eps,s=0;return;end;v=v/nv;
end
s=norm(X*v);
end
function x=local_logit(p),p=min(max(p,1e-6),1-1e-6);x=log(p/(1-p));end
function p=local_sigmoid(x),p=1./(1+exp(-max(min(x,35),-35)));end
