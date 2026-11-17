%% Assemble participant-relative sensor landscapes for the same 225 people.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));
cfg=v371_setup();out=fullfile(cfg.output_root,'04_sensor_comparator');
S=readtable(fullfile(out,'A04_sensor_extraction_status.csv'),'Delimiter',',');
for v={'subject_id','group','condition','output_file','status'},S.(v{1})=string(S.(v{1}));end
S=S(ismember(S.status,["OK","SKIPPED_EXISTS"]),:);if isempty(S),error('V371:Sensor','No sensor maps.');end
D=load(fullfile(cfg.project_root,'derivatives','V37_DCM_concordant_ROI_discovery', ...
    '03_participant_features','A03_participant_spectral_landscapes.mat'),'dataset');
P=D.dataset.participants;if height(P)~=225||any(string(P.assignment)~="discovery"),error('V371:Boundary','Discovery boundary failed.');end

% Preserve the first recording's inversion-channel order; other recordings
% are label-aligned and missing labels remain NaN.
z=load(char(S.output_file(1)),'result');labels=string(z.result.spectral.channel_label(:));
freq=double(z.result.spectral.frequency_hz(:)');n=height(P);nc=numel(labels);nf=numel(freq);
EC=nan(n,nc,nf,'single');EO=EC;rel=nan(n,nc,2,'single');epochs=nan(n,2);
for r=1:height(S)
    [ok,i]=ismember(S.subject_id(r),string(P.subject_id));if ~ok,error('V371:Boundary','Non-discovery sensor map.');end
    a=load(char(S.output_file(r)),'result');[present,loc]=ismember(labels,string(a.result.spectral.channel_label(:)));
    X=nan(nc,nf,'single');R=nan(nc,1,'single');X(present,:)=a.result.spectral.log_spectrum(loc(present),:);
    R(present)=a.result.spectral.split_half_spectral_correlation(loc(present));
    if S.condition(r)=="restEC",c=1;EC(i,:,:)=X;else,c=2;EO(i,:,:)=X;end
    rel(i,:,c)=R;epochs(i,c)=a.result.spectral.n_good_epochs;
end
EC=local_relative(EC);EO=local_relative(EO);average=local_nanmean(EC,EO);
has_EC=squeeze(any(any(isfinite(EC),2),3));has_EO=squeeze(any(any(isfinite(EO),2),3));
sensor=struct('participants',P,'frequency_hz',freq,'channel_label',labels, ...
    'average_relative_log_spectrum',average,'has_paired_conditions',has_EC&has_EO, ...
    'split_half_spectral_correlation',mean(rel,3,'omitnan'),'good_epoch_count',epochs, ...
    'representation',"condition-average log spectrum minus within-participant frequency-wise channel median", ...
    'validation_participants_read',0);
save(fullfile(out,'A05_sensor_participant_features.mat'),'sensor','cfg','-v7.3');
fprintf('Assembled sensor comparator for %d discovery participants; validation read=0.\n',n);
function X=local_relative(X)
for i=1:size(X,1),for f=1:size(X,3),v=double(X(i,:,f));if any(isfinite(v)),X(i,:,f)=v-median(v,'omitnan');end,end,end
end
function M=local_nanmean(A,B)
M=A;both=isfinite(A)&isfinite(B);M(both)=(A(both)+B(both))/2;only=~isfinite(A)&isfinite(B);M(only)=B(only);
end
