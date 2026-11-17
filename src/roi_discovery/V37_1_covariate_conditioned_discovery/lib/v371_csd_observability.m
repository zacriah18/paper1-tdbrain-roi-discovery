function audit=v371_csd_observability(cfg,recording)
%V371_CSD_OBSERVABILITY SPM-native CSD visibility for four frozen IMG nodes.
temporary=fullfile(tempdir,'V371_observability_not_inverted.mat');
DCM=v371_build_four_node_dcm_spec(cfg,recording,temporary);
DCM=spm_dcm_erp_data(DCM);DCM=spm_dcm_erp_dipfit(DCM,1);
U=spm_dcm_eeg_channelmodes(DCM.M.dipfit,cfg.peer_joint_channel_modes);DCM.M.U=U;
DCM=spm_dcm_csd_data(DCM);C=DCM.xY.csd{1};hz=double(DCM.xY.Hz(:));
K=4;dominant=zeros(size(U,2),K);sensor_dominant=zeros(size(U,1),K);
H=cell(K,1);visibility=zeros(K,1);projected_rank=zeros(K,1);projected_effective_rank=zeros(K,1);
csd_energy_fraction=zeros(K,1);frontal_polar_fraction=zeros(K,1);temporal_fraction=zeros(K,1);occipital_fraction=zeros(K,1);
labels=string(DCM.M.dipfit.Nm); %#ok<NASGU>
D=spm_eeg_load(DCM.xY.Dfile);Ic=DCM.xY.Ic;channel_labels=string(D.chanlabels(Ic))';
for i=1:K
    G=full(DCM.M.dipfit.G{i});H{i}=U'*G;[Uh,Sh,~]=svd(H{i},'econ');
    dominant(:,i)=Uh(:,1);projected_rank(i)=rank(H{i});projected_effective_rank(i)=local_effective_rank(diag(Sh));
    % U is deliberately rescaled by SPM, so this is a projection-gain
    % diagnostic rather than a bounded fraction of sensor-space energy.
    visibility(i)=norm(H{i},'fro')/max(norm(G,'fro'),eps);
    [Ug,~,~]=svd(G,'econ');sensor_dominant(:,i)=Ug(:,1);
    csd_energy_fraction(i)=local_pattern_energy(C,dominant(:,i))/max(local_total_energy(C),eps);
    w=abs(sensor_dominant(:,i)).^2;w=w/max(sum(w),eps);
    frontal_polar_fraction(i)=sum(w(ismember(upper(channel_labels),["FP1","FP2"])));
    temporal_fraction(i)=sum(w(ismember(upper(channel_labels),["F7","F8","T7","T8","P7","P8"])));
    occipital_fraction(i)=sum(w(ismember(upper(channel_labels),["O1","OZ","O2"])));
end
joint_rank=rank(dominant);singular=svd(dominant);joint_effective_rank=local_effective_rank(singular);
condition_number=singular(1)/max(singular(end),eps);unique_residual_norm=zeros(K,1);unique_csd_fraction=zeros(K,1);
for i=1:K
    Q=orth(dominant(:,setdiff(1:K,i)));residual=(eye(size(U,2))-Q*Q')*dominant(:,i);
    unique_residual_norm(i)=norm(residual);
    if norm(residual)>eps,residual=residual/norm(residual);unique_csd_fraction(i)=local_pattern_energy(C,residual)/max(local_total_energy(C),eps);end
end
pair_i=[];pair_j=[];rms_corr=[];dominant_corr=[];mean_coherence=[];mean_imaginary_coherence=[];
for i=1:K,for j=i+1:K
    s=svd(orth(H{i})'*orth(H{j}));pair_i(end+1,1)=i;pair_j(end+1,1)=j; %#ok<AGROW>
    rms_corr(end+1,1)=sqrt(mean(s.^2));dominant_corr(end+1,1)=abs(dominant(:,i)'*dominant(:,j)); %#ok<AGROW>
    [coh,icoh]=local_coherence(C,dominant(:,i),dominant(:,j));mean_coherence(end+1,1)=mean(coh);mean_imaginary_coherence(end+1,1)=mean(icoh); %#ok<AGROW>
end,end
node=table((1:K)',[385;5;261;314],visibility,projected_rank,projected_effective_rank, ...
    csd_energy_fraction,unique_residual_norm,unique_csd_fraction,frontal_polar_fraction, ...
    temporal_fraction,occipital_fraction,'VariableNames',{'node','patch_id','channel_mode_visibility', ...
    'projected_regional_rank','projected_effective_rank','CSD_energy_fraction', ...
    'unique_residual_norm','unique_CSD_energy_fraction','frontal_polar_leadfield_fraction', ...
    'temporal_leadfield_fraction','occipital_leadfield_fraction'});
pair=table(pair_i,pair_j,rms_corr,dominant_corr,mean_coherence,mean_imaginary_coherence, ...
    'VariableNames',{'node_i','node_j','projected_rms_canonical_correlation', ...
    'dominant_pattern_correlation','mean_coherence','mean_imaginary_coherence'});
audit=struct('pipeline_version',cfg.peer_pipeline_version,'subject_id',string(DCM.V371.subject_id), ...
    'group',string(DCM.V371.group),'condition',string(DCM.V371.condition),'source_file',string(DCM.xY.Dfile), ...
    'frequency_hz',hz,'channel_labels',channel_labels,'node',node,'pair',pair, ...
    'joint_dominant_rank',joint_rank,'joint_effective_rank',joint_effective_rank, ...
    'joint_condition_number',condition_number,'channel_modes',size(U,2), ...
    'minimum_unique_residual_norm',min(unique_residual_norm), ...
    'numerical_noncollapse_pass',joint_rank==K&&min(unique_residual_norm)>1e-3);
end
function energy=local_pattern_energy(C,g)
energy=0;for f=1:size(C,1),Cf=squeeze(C(f,:,:));energy=energy+real(g'*Cf*g);end;energy=energy/size(C,1);
end
function energy=local_total_energy(C)
energy=0;for f=1:size(C,1),energy=energy+real(trace(squeeze(C(f,:,:))));end;energy=energy/size(C,1);
end
function [coh,icoh]=local_coherence(C,a,b)
nf=size(C,1);coh=zeros(nf,1);icoh=zeros(nf,1);
for f=1:nf,Cf=squeeze(C(f,:,:));sij=a'*Cf*b;sii=max(real(a'*Cf*a),eps);sjj=max(real(b'*Cf*b),eps);den=sqrt(sii*sjj);coh(f)=abs(sij)^2/(sii*sjj);icoh(f)=abs(imag(sij))/den;end
end
function r=local_effective_rank(s)
s=double(s(:));p=(s.^2)/max(sum(s.^2),eps);r=exp(-sum(p.*log(max(p,eps))));
end
