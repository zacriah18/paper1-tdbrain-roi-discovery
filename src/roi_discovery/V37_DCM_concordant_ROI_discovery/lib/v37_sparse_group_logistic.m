function model = v37_sparse_group_logistic(X, y, groups, lambda, alpha, cfg)
%V37_SPARSE_GROUP_LOGISTIC FISTA sparse-group logistic regression.
X = double(X); y = double(y(:)); groups = double(groups(:));
[n,p] = size(X); beta = zeros(p,1); z = beta; intercept = local_logit(mean(y));
zi = intercept; t = 1;
spectral_norm = local_spectral_norm(X);
L = 0.25 * (spectral_norm^2/n + 1) + 1e-8;
step = 1/L;
ug = unique(groups(:))';

for iter = 1:cfg.optim_max_iterations
    eta = X*z + zi;
    prob = local_sigmoid(eta);
    gb = X'*(prob-y)/n;
    gi = mean(prob-y);
    bnew = z - step*gb;
    bnew = sign(bnew).*max(abs(bnew)-step*lambda*alpha,0);
    if alpha < 1
        for g = ug
            idx = groups == g;
            v = bnew(idx);
            threshold = step*lambda*(1-alpha)*sqrt(sum(idx));
            bnew(idx) = max(1-threshold/max(norm(v),eps),0)*v;
        end
    end
    inew = zi - step*gi;
    tnew = (1+sqrt(1+4*t^2))/2;
    z = bnew + ((t-1)/tnew)*(bnew-beta);
    zi = inew + ((t-1)/tnew)*(inew-intercept);
    change = norm(bnew-beta)/max(1,norm(beta));
    beta = bnew; intercept = inew; t = tnew;
    if change < cfg.optim_tolerance, break; end
end
model = struct('beta',beta,'intercept',intercept,'iterations',iter, ...
    'lambda',lambda,'alpha',alpha);
end

function s = local_spectral_norm(X)
if isempty(X), s = 0; return; end
v = ones(size(X,2),1); v = v/norm(v);
for i = 1:25
    v = X'*(X*v); nv = norm(v);
    if nv <= eps, s = 0; return; end
    v = v/nv;
end
s = norm(X*v);
end
function x = local_logit(p), p=min(max(p,1e-6),1-1e-6); x=log(p/(1-p)); end
function p = local_sigmoid(x), p=1./(1+exp(-max(min(x,35),-35))); end
