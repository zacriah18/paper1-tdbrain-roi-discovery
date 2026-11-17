function m = v371_metrics(y,p)
%V371_METRICS Prediction metrics and calibration from cross-fitted scores.
y=double(y(:));p=min(max(double(p(:)),1e-8),1-1e-8);label=p>=0.5;
m=struct();m.AUC=v37_auc(y,p);
m.log_loss=-mean(y.*log(p)+(1-y).*log(1-p));
m.Brier=mean((p-y).^2);m.sensitivity=mean(label(y==1));
m.specificity=mean(~label(y==0));
m.balanced_accuracy=mean([m.sensitivity,m.specificity]);
lp=log(p./(1-p));cal=v37_ridge_logistic(lp,y,1e-8);
m.calibration_intercept=cal.beta(1);m.calibration_slope=cal.beta(2);
end
