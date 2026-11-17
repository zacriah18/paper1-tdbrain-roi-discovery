function out=v35_granger_sensitivity(epochs,cfg)
% Pairwise bivariate VAR sensitivity, repeated after instantaneous whitening.
nnode=size(epochs{1},1);out.raw_trgc=zeros(nnode);out.whitened_trgc=zeros(nnode);
out.raw_time_reversal_consistent=false(nnode);out.whitened_time_reversal_consistent=false(nnode);
out.raw_forward_difference=zeros(nnode);out.whitened_forward_difference=zeros(nnode);
for i=1:nnode,for j=i+1:nnode
    pair=cellfun(@(x)standardize(x([i j],:)),epochs,'UniformOutput',false);
    [gf,gr]=forward_reverse(pair,cfg.granger_order_samples);
    d=gf(1)-gf(2);dr=gr(1)-gr(2);tr=.5*(d-dr);
    out.raw_trgc(i,j)=tr;out.raw_trgc(j,i)=-tr;out.raw_forward_difference(i,j)=d;out.raw_forward_difference(j,i)=-d;
    ok=sign(d)==-sign(dr)&&sign(d)~=0;out.raw_time_reversal_consistent(i,j)=ok;out.raw_time_reversal_consistent(j,i)=ok;
    white=whiten(pair,cfg.whitening_eigenvalue_floor);[gf,gr]=forward_reverse(white,cfg.granger_order_samples);
    d=gf(1)-gf(2);dr=gr(1)-gr(2);tr=.5*(d-dr);
    out.whitened_trgc(i,j)=tr;out.whitened_trgc(j,i)=-tr;out.whitened_forward_difference(i,j)=d;out.whitened_forward_difference(j,i)=-d;
    ok=sign(d)==-sign(dr)&&sign(d)~=0;out.whitened_time_reversal_consistent(i,j)=ok;out.whitened_time_reversal_consistent(j,i)=ok;
end,end
end

function X=standardize(X),X=X-mean(X,2);X=X./max(std(X,0,2),eps);end
function out=whiten(epochs,floor_value)
X=[epochs{:}];C=(X*X')/size(X,2);[V,D]=eig((C+C')/2);d=diag(D);d=max(d,max(d)*floor_value);
W=V*diag(1./sqrt(d))*V';out=cellfun(@(x)W*x,epochs,'UniformOutput',false);
end
function [forward,reverse]=forward_reverse(epochs,p)
forward=fit_pair(epochs,p);reverse=fit_pair(cellfun(@fliplr,epochs,'UniformOutput',false),p);
end
function gc=fit_pair(epochs,p)
Z=[];Y=[];
for e=1:numel(epochs)
    x=epochs{e};nt=size(x,2);if nt<=p+2,continue;end
    z=zeros(nt-p,2*p);
    for lag=1:p,z(:,lag)=x(1,p+1-lag:nt-lag)';z(:,p+lag)=x(2,p+1-lag:nt-lag)';end
    Z=[Z;z];Y=[Y;x(:,p+1:nt)']; %#ok<AGROW>
end
if size(Z,1)<20*p,gc=[NaN NaN];return;end
full=[ones(size(Z,1),1) Z];B=pinv(full)*Y;E=Y-full*B;vf=sum(E.^2,1)/size(E,1);
r1=[ones(size(Z,1),1) Z(:,1:p)];b=pinv(r1)*Y(:,1);e=Y(:,1)-r1*b;v1=sum(e.^2)/numel(e);
r2=[ones(size(Z,1),1) Z(:,p+1:end)];b=pinv(r2)*Y(:,2);e=Y(:,2)-r2*b;v2=sum(e.^2)/numel(e);
gc=[log(max(v2,eps)/max(vf(2),eps)) log(max(v1,eps)/max(vf(1),eps))]; % [1->2, 2->1]
end
