function [Xtrain, Xtest, prep] = v37_prepare_matrix(X, train, test)
%V37_PREPARE_MATRIX Training-only imputation and standardization.
Xtrain = double(X(train,:));
Xtest = double(X(test,:));
med = median(Xtrain,1,'omitnan'); med(~isfinite(med)) = 0;
for j = 1:size(X,2)
    Xtrain(~isfinite(Xtrain(:,j)),j) = med(j);
    Xtest(~isfinite(Xtest(:,j)),j) = med(j);
end
mu = mean(Xtrain,1); sigma = std(Xtrain,0,1);
sigma(~isfinite(sigma) | sigma < 1e-10) = 1;
Xtrain = (Xtrain - mu) ./ sigma;
Xtest = (Xtest - mu) ./ sigma;
prep = struct('median',med,'mean',mu,'std',sigma);
end
