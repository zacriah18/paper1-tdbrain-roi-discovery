%% EO sensor-spectrum and frontal-polar proxy audit for the frozen ROI signal.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'07_pre_DCM_gate');maps=fullfile(out,'EO_sensor_maps');
if ~exist(maps,'dir'),mkdir(maps);end
S=readtable(fullfile(cfg.output_root,'06_heldout_validation','A09_validation_extraction_status.csv'), ...
    'Delimiter',',','TextType','string','VariableNamingRule','preserve');
S=S(ismember(string(S.status),["OK","SKIPPED_EXISTS"])&string(S.condition)=="restEO",:);
run_status=S(:,{'subject_id','group','condition','source_file'});n=height(run_status);
run_status.output_file=strings(n,1);run_status.status=repmat("PENDING",n,1);
run_status.message=strings(n,1);run_status.elapsed_seconds=nan(n,1);
for r=1:n
    tic;file=fullfile(maps,char(run_status.subject_id(r)+"_"+run_status.group(r)+"_restEO_V371_sensor.mat"));
    run_status.output_file(r)=string(file);
    if cfg.resume&&exist(file,'file')
        run_status.status(r)="SKIPPED_EXISTS";
    else
        try
            D=spm_eeg_load(char(run_status.source_file(r)));spectral=v371_sensor_spectra(D,cfg);
            result=struct('pipeline_version',cfg.peer_pipeline_version,'subject_id',run_status.subject_id(r), ...
                'group',run_status.group(r),'condition',"restEO",'source_file',run_status.source_file(r), ...
                'spectral',spectral,'role',"EO sensor and frontal-polar proxy audit; not an EOG measurement");
            save(file,'result','cfg','-v7.3');run_status.status(r)="OK";
        catch ME
            run_status.status(r)="ERROR";run_status.message(r)=string(ME.identifier)+": "+string(ME.message);
        end
    end
    run_status.elapsed_seconds(r)=toc;
    writetable(run_status,fullfile(out,'A14_EO_sensor_extraction_status.csv'));
    fprintf('%d/%d %s %s (%.1fs)\n',r,n,run_status.subject_id(r),run_status.status(r),run_status.elapsed_seconds(r));
end
writetable(run_status,fullfile(out,'A14_EO_sensor_extraction_status.csv'));
local_analyse(run_status,cfg,out);

function local_analyse(run_status,cfg,out)
run_status=run_status(ismember(run_status.status,["OK","SKIPPED_EXISTS"]),:);
if isempty(run_status),error('V371:EOSensor','No EO sensor maps were available.');end
peer=load(fullfile(cfg.output_root,'05_peer_set_comparison','A08_peer_set_comparison.mat'),'result');R=peer.result;
split=readtable(fullfile(cfg.project_root,'derivatives','V32_induced','05_frozen_split','A05_participant_split_LOCKED.csv'), ...
    'Delimiter',',','TextType','string');split=split(string(split.assignment)=="validation",:);
z=load(char(run_status.output_file(1)),'result');labels=string(z.result.spectral.channel_label(:));
freq=double(z.result.spectral.frequency_hz(:)');n=height(run_status);nc=numel(labels);nf=numel(freq);
sensor_log=nan(n,nc,nf);source_coeff=nan(n,6);P=table();
status_all=readtable(fullfile(cfg.output_root,'06_heldout_validation','A09_validation_extraction_status.csv'), ...
    'Delimiter',',','TextType','string','VariableNamingRule','preserve');
for r=1:n
    a=load(char(run_status.output_file(r)),'result');[present,loc]=ismember(labels,string(a.result.spectral.channel_label(:)));
    sensor_log(r,present,:)=a.result.spectral.log_spectrum(loc(present),:);
    source_row=status_all(string(status_all.subject_id)==run_status.subject_id(r)&string(status_all.condition)=="restEO",:);
    source=load(char(source_row.output_file(1)),'result');X=double(source.result.spectral.log_spectrum);
    X=X-median(X,1,'omitnan');source_coeff(r,:)=X(385,:)*R.spectral_basis;
    prow=split(string(split.subject_id)==run_status.subject_id(r),:);P=[P;prow]; %#ok<AGROW>
end
for r=1:n,for f=1:nf,v=squeeze(sensor_log(r,:,f));sensor_log(r,:,f)=v-median(v,'omitnan');end,end
coeff=reshape(reshape(sensor_log,n*nc,nf)*R.spectral_basis,n,nc,6);
[Z,~,sex_binary]=v371_nuisance_matrix(P);Z=[ones(n,1),Z];y=double(string(P.group)=="MDD");
key=string(P.age_band)+"|sex="+string(sex_binary)+"|condition="+string(P.condition_availability);
[blocks,~,block_id]=unique(key,'stable');B=cfg.validation_fixed_permutation_count;
stat=zeros(nc,1);p=zeros(nc,1);rho=zeros(nc,1);source_p=zeros(nc,1);
beta=double(R.frozen_model.model.beta(:));scale=reshape(double(R.frozen_model.neural_scale),1,[]);
mu=reshape(double(R.frozen_model.neural_mean),1,[]);source_score=((source_coeff-mu)./scale)*beta;
stream=RandStream('mt19937ar','Seed',cfg.validation_fixed_permutation_seed+240000);
for c=1:nc
    X=squeeze(coeff(:,c,:));X=X-Z*(Z\X);good=all(isfinite(X),2)&isfinite(source_score);
    X=X(good,:);yc=y(good);bid=block_id(good);[stat(c),null]=local_conditional_multivariate(X,yc,bid,B,stream);
    p(c)=(1+sum(null>=stat(c)))/(B+1);
    Xz=(X-mean(X,1))./max(std(X,0,1),eps);sensor_score=Xz*(beta/max(norm(beta),eps));
    rho(c)=corr(sensor_score,source_score(good),'Type','Spearman','Rows','complete');
    source_p(c)=local_spearman_p(rho(c),sum(good));
end
holm=local_holm(p);source_holm=local_holm(source_p);
channel=table(labels,stat,p,holm,rho,source_p,source_holm,ismember(upper(labels),["FP1","FP2"]), ...
    'VariableNames',{'channel','conditional_multivariate_statistic','conditional_p_value','Holm_p_value', ...
    'Spearman_rho_with_frozen_patch385_EO_score','Spearman_p_value','Spearman_Holm_p_value','frontal_polar_proxy'});
channel=sortrows(channel,{'Holm_p_value','conditional_p_value'});
writetable(channel,fullfile(out,'A14_EO_sensor_ocular_proxy_audit.csv'));
fp=channel(channel.frontal_polar_proxy,:);summary=table(n,nc,B,min(channel.Holm_p_value),sum(channel.Holm_p_value<.05), ...
    min(fp.Holm_p_value),sum(fp.Holm_p_value<.05),max(abs(fp.Spearman_rho_with_frozen_patch385_EO_score)), ...
    "Fp1/Fp2 are frontal-polar EEG proxies; no dedicated EOG channels are present", ...
    'VariableNames',{'EO_participants','EEG_channels','conditional_permutations','minimum_channel_Holm_p', ...
    'Holm_positive_channels','minimum_frontal_polar_Holm_p','Holm_positive_frontal_polar_channels', ...
    'maximum_absolute_frontal_polar_source_score_correlation','ocular_audit_limitation'});
writetable(summary,fullfile(out,'A14_EO_sensor_ocular_proxy_summary.csv'));
save(fullfile(out,'A14_EO_sensor_ocular_proxy_results.mat'),'channel','summary','coeff','source_coeff','source_score','P','blocks','cfg','-v7.3');
end

function [stat,null]=local_conditional_multivariate(X,y,block_id,B,stream)
d=mean(X(y==1,:),1)-mean(X(y==0,:),1);C=cov(X);C=C+1e-3*trace(C)/size(C,1)*eye(size(C));stat=d*(C\d');
null=zeros(B,1);for b=1:B,yp=y;for k=1:max(block_id),idx=find(block_id==k);if numel(idx)>1,yp(idx)=y(idx(randperm(stream,numel(idx))));end,end
    db=mean(X(yp==1,:),1)-mean(X(yp==0,:),1);null(b)=db*(C\db');end
end
function adjusted=local_holm(p)
[s,ord]=sort(p);m=numel(p);a=zeros(m,1);running=0;for i=1:m,running=max(running,min(1,(m-i+1)*s(i)));a(i)=running;end
adjusted=zeros(m,1);adjusted(ord)=a;
end
function p=local_spearman_p(r,n)
if ~isfinite(r)||n<4,p=NaN;return;end;t=abs(r)*sqrt((n-2)/max(1-r^2,eps));p=2*(1-tcdf(t,n-2));
end
