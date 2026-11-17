function spectral = v371_sensor_spectra(D,cfg)
%V371_SENSOR_SPECTRA Sensor-level comparator on the inversion-visible data.
% Uses the saved inverse's channels and time samples, but applies no source
% operator. This makes it a negative-control comparator for spatial source
% claims rather than a second source reconstruction.
[~,inverse] = v32_get_inverse(D,cfg.inverse_index);
Ic = inverse.Ic; if iscell(Ic), Ic = Ic{1}; end
It = inverse.It;
try, labs = inverse.trials; catch, labs = D.condlist; end
if ischar(labs)||isstring(labs), labs=cellstr(labs); end
good = D.indtrial(labs{1},'GOOD');
if numel(good)<cfg.minimum_good_epochs
    error('V371:EpochCount','Only %d good epochs.',numel(good));
end

fs=double(D.fsample); ntime=numel(It);
w=min(fix(cfg.spectral_window_seconds*fs),ntime);
if w<16,error('V371:Window','Spectral window is too short.');end
nwindows=max(8*(fix(ntime/w)-1),1);
starts=1+fix((0:nwindows-1)*w/8); starts(starts+w-1>ntime)=[];
taper=0.5-0.5*cos(2*pi*(0:w-1)/max(w-1,1));
bins=round(cfg.frequency_hz*w/fs)+1;
if any(bins>w),error('V371:Frequency','Requested frequency exceeds FFT grid.');end

nch=numel(Ic); nf=numel(cfg.frequency_hz);
all_power=zeros(nch,nf); odd_power=zeros(nch,nf); even_power=zeros(nch,nf);
nall=0;nodd=0;neven=0;
for e=1:numel(good)
    raw=double(D(Ic,It,good(e)));
    for k=1:numel(starts)
        iw=starts(k)+(0:w-1); F=fft(raw(:,iw).*taper,[],2);
        P=abs(F(:,bins)).^2/max(sum(taper.^2)*fs,eps);
        all_power=all_power+P;nall=nall+1;
        if mod(e,2),odd_power=odd_power+P;nodd=nodd+1;
        else,even_power=even_power+P;neven=neven+1;end
    end
end
all_power=all_power/max(nall,1); odd_power=odd_power/max(nodd,1);
even_power=even_power/max(neven,1); floor_value=realmin('single');
log_spectrum=log(max(all_power,floor_value)); split_corr=nan(nch,1);
for c=1:nch
    split_corr(c)=local_corr(log(max(odd_power(c,:),floor_value))', ...
        log(max(even_power(c,:),floor_value))');
end
spectral=struct('frequency_hz',double(cfg.frequency_hz(:)'), ...
    'channel_label',string(D.chanlabels(Ic))', ...
    'log_spectrum',single(log_spectrum), ...
    'split_half_spectral_correlation',split_corr, ...
    'n_good_epochs',numel(good),'n_windows_per_epoch',numel(starts), ...
    'fsample',fs,'inverse_index',cfg.inverse_index);
end
function r=local_corr(a,b)
a=a-mean(a);b=b-mean(b);r=(a'*b)/sqrt(max((a'*a)*(b'*b),eps));
end
