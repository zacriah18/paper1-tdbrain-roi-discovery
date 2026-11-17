%% Reproduce SPM's exact IMG patch construction before any DCM inversion.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v36_setup();
out=fullfile(cfg.output_root,'01_preflight');if ~exist(out,'dir'),mkdir(out);end
status=v36_discovery_recordings(cfg);if isempty(status),error('V36:Inventory','No discovery recordings.');end
recording=status(1,:);template_file=fullfile(out,'A01_preflight_template_not_inverted.mat');
DCM=v36_build_dcm_spec(cfg,recording,template_file);DCM=spm_dcm_erp_data(DCM);DCM=spm_dcm_erp_dipfit(DCM,1);
nodes=readtable(cfg.node_manifest,'Delimiter',',');nodes=sortrows(nodes,'dcm_node_number');D=spm_eeg_load(char(recording.source_file));
vert=D.inv{D.val}.mesh.tess_mni.vert;if ischar(vert),vert=gifti(vert).vertices;end;vert=double(vert);
node_table=table();Q=cell(6,1);allG=[];
for i=1:6
    ip=DCM.M.dipfit.Ip{i};G=full(DCM.M.dipfit.G{i});Q{i}=orth(G);allG=[allG G]; %#ok<AGROW>
    dist=sqrt(sum((vert(ip,:)-DCM.Lpos(:,i)').^2,2));sv=svd(G);
    row=table(i,nodes.patch_id(i),DCM.Lpos(1,i),DCM.Lpos(2,i),DCM.Lpos(3,i),numel(ip),max(dist),rank(G),effective_rank(sv), ...
        'VariableNames',{'dcm_node','patch_id','x','y','z','spm_IMG_vertices','maximum_Euclidean_radius_mm','regional_mode_rank','regional_effective_rank'});node_table=[node_table;row]; %#ok<AGROW>
end
pair=table();
for i=1:6,for j=i+1:6
    s=svd(Q{i}'*Q{j});row=table(i,j,max(s),sqrt(mean(s.^2)), ...
        'VariableNames',{'node_i','node_j','maximum_canonical_correlation','rms_canonical_correlation'});pair=[pair;row]; %#ok<AGROW>
end,end
U=spm_dcm_eeg_channelmodes(DCM.M.dipfit,cfg.channel_modes);sv=svd(allG);
summary=table(rank(allG),effective_rank(sv),size(allG,1),size(allG,2),size(U,2), ...
    'VariableNames',{'combined_regional_leadfield_rank','combined_regional_effective_rank','good_EEG_channels','regional_basis_columns','DCM_channel_modes'});
writetable(node_table,fullfile(out,'A01_exact_SPM_IMG_node_geometry.csv'));writetable(pair,fullfile(out,'A01_exact_SPM_IMG_pairwise_subspaces.csv'));
writetable(summary,fullfile(out,'A01_exact_SPM_IMG_summary.csv'));save(template_file,'DCM','node_table','pair','summary','cfg','-v7.3');
fprintf('Exact IMG preflight: rank %d, effective rank %.2f, %d channel modes.\n',summary.combined_regional_leadfield_rank,summary.combined_regional_effective_rank,summary.DCM_channel_modes);
function r=effective_rank(s),p=(s.^2)/sum(s.^2);r=exp(-sum(p.*log(max(p,eps))));end
