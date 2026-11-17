%% Extract broadband spatial and epoch metrics for every local patch.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v34_setup();
out=fullfile(cfg.output_root,'02_patch_metrics');if ~exist(out,'dir'),mkdir(out);end
P=load(fullfile(cfg.output_root,'01_patch_tiling','A01_DCM_aligned_16mm_patches.mat'),'patches');patches=P.patches;
membership=patches.membership;counts=full(sum(membership,1))';W=membership*spdiags(1./counts,0,numel(counts),numel(counts));
B=membership*spdiags(1./sqrt(counts),0,numel(counts),numel(counts));npatch=numel(counts);
status=readtable(fullfile(cfg.project_root,'derivatives','V33_broadband_mesh','02_recording_maps','A02_extraction_status.csv'),'Delimiter',',');
for v={'subject_id','group','condition','source_file','output_file','status'},status.(v{1})=string(status.(v{1}));end
status=status(ismember(status.status,["OK","SKIPPED_EXISTS"]),:);
split=readtable(fullfile(cfg.project_root,'derivatives','V32_induced','05_frozen_split','A05_participant_split_LOCKED.csv'),'Delimiter',',');
split.subject_id=string(split.subject_id);split.assignment=string(split.assignment);
n=height(status)*npatch;sid=strings(n,1);grp=strings(n,1);cond=strings(n,1);assignment=strings(n,1);patch=zeros(n,1);
mean_pct=nan(n,1);mean_log=nan(n,1);median_log=nan(n,1);upper_vertex=nan(n,1);peak_prom=nan(n,1);precision=nan(n,1);
epoch_mad=nan(n,1);epoch_sd=nan(n,1);burst=nan(n,1);half1=nan(n,1);half2=nan(n,1);ngood=zeros(n,1);cursor=0;
mean_psf=zeros(npatch,npatch);mean_ctf=zeros(npatch,npatch);nprofiles=0;
for i=1:height(status)
    loaded=load(char(status.output_file(i)),'result');r=loaded.result;loc=find(split.subject_id==status.subject_id(i),1);
    D=spm_eeg_load(char(status.source_file(i)));temporal=v34_epoch_patch_metrics(D,cfg,W);
    logv=double(r.log_broadband_energy);pct=double(r.percentile_log_broadband_energy);e=double(r.mean_broadband_energy);pv=double(r.posterior_variance);
    for p=1:npatch
        cursor=cursor+1;vv=membership(:,p)>0;sid(cursor)=status.subject_id(i);grp(cursor)=status.group(i);cond(cursor)=status.condition(i);assignment(cursor)=split.assignment(loc);patch(cursor)=p;
        mean_pct(cursor)=mean(pct(vv));mean_log(cursor)=mean(logv(vv));median_log(cursor)=median(logv(vv));upper_vertex(cursor)=prctile(logv(vv),90);peak_prom(cursor)=max(logv(vv))-mean(logv(vv));
        precision(cursor)=mean(e(vv)./(e(vv)+pv(vv)+eps));epoch_mad(cursor)=temporal.log_mad(p);epoch_sd(cursor)=temporal.log_sd(p);burst(cursor)=temporal.burst_prominence(p);half1(cursor)=temporal.half1_log(p);half2(cursor)=temporal.half2_log(p);ngood(cursor)=temporal.n_good_trials;
    end
    if split.assignment(loc)=="discovery"
        [~,inverse]=v32_get_inverse(D,cfg.inverse_index);A=full((B'*double(inverse.M))*(double(inverse.L)*B));
        psf=normcols(abs(A));ctf=normcols(abs(A'));mean_psf=mean_psf+psf;mean_ctf=mean_ctf+ctf;nprofiles=nprofiles+1;
    end
    fprintf('%d/%d %s %s\n',i,height(status),status.subject_id(i),status.condition(i));
end
metrics=table(sid,grp,cond,assignment,patch,ngood,mean_pct,mean_log,median_log,upper_vertex,peak_prom,precision,epoch_mad,epoch_sd,burst,half1,half2, ...
    'VariableNames',{'subject_id','group','condition','assignment','patch_id','n_good_trials','mean_percentile_energy','mean_log_energy','median_log_energy','upper_vertex_log_energy','spatial_peak_prominence','posterior_precision','epoch_log_mad','epoch_log_sd','temporal_burst_prominence','half1_log_energy','half2_log_energy'});
mean_psf=mean_psf/nprofiles;mean_ctf=mean_ctf/nprofiles;
writetable(metrics,fullfile(out,'A02_DCM_aligned_patch_metrics.csv'));save(fullfile(out,'A02_DCM_aligned_patch_metrics.mat'),'metrics','mean_psf','mean_ctf','patches','cfg','-v7.3');
fprintf('Wrote %d recording-patch rows and %d diagnosis-blind discovery resolution profiles.\n',height(metrics),nprofiles);
function X=normcols(X),z=sqrt(sum(X.^2,1));z(z==0)=1;X=X./z;end
