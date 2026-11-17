function model = v37_ridge_logistic(X,y,lambda)
%V37_RIDGE_LOGISTIC Small Newton solver for nuisance benchmarks.
X = [ones(size(X,1),1), double(X)]; y = double(y(:));
b = zeros(size(X,2),1); P = diag([0;ones(size(X,2)-1,1)]);
for it = 1:100
    p = 1./(1+exp(-max(min(X*b,35),-35)));
    w = max(p.*(1-p),1e-6);
    g = X'*(p-y) + lambda*P*b;
    H = X'*(X.*w) + lambda*P + 1e-8*eye(size(X,2));
    step = H\g; b = b-step;
    if norm(step)<1e-8, break; end
end
model = struct('beta',b,'iterations',it);
end
