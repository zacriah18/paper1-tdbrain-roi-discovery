function out=v34_epoch_patch_metrics(D,cfg,W)
% Per-epoch broadband energy aggregated directly into local patches.
[~,inverse]=v32_get_inverse(D,cfg.inverse_index);T=double(inverse.T);ntime=size(T,1);
try,labs=inverse.trials;catch,labs=D.condlist;end;if ischar(labs)||isstring(labs),labs=cellstr(labs);end
good=D.indtrial(labs{1},'GOOD');U=inverse.U;Ic=inverse.Ic;if ~iscell(U),U={U};end;if ~iscell(Ic),Ic={Ic};end
try,scale=inverse.scale;catch,scale=1;end;if numel(scale)>1,scale=scale(1);end
M=double(inverse.M);epoch_energy=zeros(numel(good),size(W,2));
for j=1:numel(good)
    raw=double(D(Ic{1},inverse.It,good(j)));C=M*(double(U{1})*(raw*T)*double(scale));
    vertex=sum(C.^2,2)/ntime;epoch_energy(j,:)=full(W'*vertex)';
end
log_epoch=log(max(epoch_energy,double(cfg.log_floor)));
out=struct('n_good_trials',numel(good),'log_mad',mad(log_epoch,1,1), ...
    'log_sd',std(log_epoch,0,1),'burst_prominence',max(log_epoch,[],1)-median(log_epoch,1), ...
    'half1_log',log(mean(epoch_energy(1:2:end,:),1)), ...
    'half2_log',log(mean(epoch_energy(2:2:end,:),1)));
end
