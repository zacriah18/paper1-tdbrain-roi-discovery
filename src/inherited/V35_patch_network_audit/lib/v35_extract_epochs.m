function [epochs,fs,good]=v35_extract_epochs(D,cfg,node)
% Reconstruct one dominant local-basis time series per patch and epoch.
inverse=node.inverse;T=double(inverse.T);projector=T*T';
try,labs=inverse.trials;catch,labs=D.condlist;end
if ischar(labs)||isstring(labs),labs=cellstr(labs);end
good=D.indtrial(labs{1},'GOOD');Ic=inverse.Ic;if ~iscell(Ic),Ic={Ic};end
try,scale=inverse.scale;catch,scale=1;end
if numel(scale)>1,scale=scale(1);end
fs=double(D.fsample);epochs=cell(numel(good),1);
for e=1:numel(good)
    raw=double(D(Ic{1},inverse.It,good(e)));
    Y=(node.filters*raw)*projector*double(scale);
    Y=Y-mean(Y,2);epochs{e}=v35_resample(Y,fs,cfg.connectivity_target_fsample);
end
fs=cfg.connectivity_target_fsample;
end

function Y=v35_resample(Y,oldfs,newfs)
if abs(oldfs-newfs)<1e-9,return;end
[p,q]=rat(newfs/oldfs,1e-10);
if exist('resample','file')==2
    Y=resample(Y',p,q)';
else
    error('V35:ResampleUnavailable','Signal Processing Toolbox resample() is required for anti-aliased downsampling.');
end
end
