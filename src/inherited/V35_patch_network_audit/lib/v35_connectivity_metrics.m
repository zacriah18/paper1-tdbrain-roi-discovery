function out=v35_connectivity_metrics(epochs,fs,cfg)
% Whole-range cross-spectral summaries; no frequency band is used for selection.
nnode=size(epochs{1},1);nt=min(cellfun(@(x)size(x,2),epochs));
taper=.5-.5*cos(2*pi*(0:nt-1)/max(nt-1,1));
freq=(0:nt-1)*(fs/nt);keep=find(freq>=cfg.connectivity_frequency_hz(1)&freq<=cfg.connectivity_frequency_hz(2));
freq=freq(keep);nf=numel(freq);S=zeros(nnode,nnode,nf);imag_sum=zeros(nnode,nnode,nf);imag_abs=zeros(nnode,nnode,nf);
used=0;
for e=1:numel(epochs)
    Y=epochs{e}(:,1:nt);sd=std(Y,0,2);if any(~isfinite(sd)|sd<=eps),continue;end
    Y=(Y-mean(Y,2))./sd;F=fft(Y.*taper,[],2);F=F(:,keep);used=used+1;
    for f=1:nf
        cross=F(:,f)*F(:,f)';S(:,:,f)=S(:,:,f)+cross;
        im=imag(cross);imag_sum(:,:,f)=imag_sum(:,:,f)+im;imag_abs(:,:,f)=imag_abs(:,:,f)+abs(im);
    end
end
if used<2,error('V35:Spectra','Too few usable epochs for cross-spectral metrics.');end
S=S/used;coh=zeros(nnode,nnode,nf);
for f=1:nf
    power=max(real(diag(S(:,:,f))),eps);den=sqrt(power*power');coh(:,:,f)=S(:,:,f)./den;
end
out.coherence=mean(abs(coh).^2,3);out.abs_imaginary_coherency=mean(abs(imag(coh)),3);
out.wpli=mean(abs(imag_sum)./max(imag_abs,eps),3);out.phase_slope=zeros(nnode);
for i=1:nnode,for j=i+1:nnode
    c=squeeze(coh(i,j,:));value=mean(imag(conj(c(1:end-1)).*c(2:end)));
    out.phase_slope(i,j)=value;out.phase_slope(j,i)=-value;
end,end
out.frequency_hz=freq;out.coherency=coh;out.n_epochs=used;
end
