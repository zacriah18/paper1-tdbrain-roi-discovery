%% Extract descriptive 12-node connectivity and Granger sensitivity metrics.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v35_setup();
out=fullfile(cfg.output_root,'02_connectivity');if ~exist(out,'dir'),mkdir(out);end
P=load(fullfile(cfg.project_root,'derivatives','V34_DCM_aligned_patches', ...
    '01_patch_tiling','A01_DCM_aligned_16mm_patches.mat'),'patches');patches=P.patches;
C=load(fullfile(cfg.project_root,'derivatives','V34_DCM_aligned_patches', ...
    '03_candidates','A03_DCM_aligned_candidate_results.mat'),'candidates');candidates=sortrows(C.candidates,'candidate_rank');
patch_ids=candidates.patch_id;nnode=numel(patch_ids);status=v35_discovery_recordings(cfg);npair=nchoosek(nnode,2);nmax=height(status)*npair;

subject_id=strings(nmax,1);group=strings(nmax,1);condition=strings(nmax,1);rank_i=zeros(nmax,1);rank_j=zeros(nmax,1);
patch_i=zeros(nmax,1);patch_j=zeros(nmax,1);coherence=nan(nmax,1);abs_imag=nan(nmax,1);wpli=nan(nmax,1);phase_slope=nan(nmax,1);
raw_trgc=nan(nmax,1);white_trgc=nan(nmax,1);raw_tr_ok=false(nmax,1);white_tr_ok=false(nmax,1);direction_agreement=false(nmax,1);cursor=0;
qc_subject=strings(height(status),1);qc_condition=strings(height(status),1);qc_group=strings(height(status),1);qc_status=strings(height(status),1);
qc_message=strings(height(status),1);qc_good=zeros(height(status),1);qc_original_fs=nan(height(status),1);qc_analysis_fs=nan(height(status),1);qc_samples=nan(height(status),1);
for r=1:height(status)
    qc_subject(r)=status.subject_id(r);qc_condition(r)=status.condition(r);qc_group(r)=status.group(r);
    try
        D=spm_eeg_load(char(status.source_file(r)));qc_original_fs(r)=double(D.fsample);
        node=v35_node_operator(D,cfg,patches,patch_ids);[epochs,fs,good]=v35_extract_epochs(D,cfg,node);
        qc_good(r)=numel(good);qc_analysis_fs(r)=fs;qc_samples(r)=size(epochs{1},2);
        spectral=v35_connectivity_metrics(epochs,fs,cfg);granger=v35_granger_sensitivity(epochs,cfg);qc_status(r)="OK";
        for i=1:nnode,for j=i+1:nnode
            cursor=cursor+1;subject_id(cursor)=status.subject_id(r);group(cursor)=status.group(r);condition(cursor)=status.condition(r);
            rank_i(cursor)=i;rank_j(cursor)=j;patch_i(cursor)=patch_ids(i);patch_j(cursor)=patch_ids(j);
            coherence(cursor)=spectral.coherence(i,j);abs_imag(cursor)=spectral.abs_imaginary_coherency(i,j);wpli(cursor)=spectral.wpli(i,j);
            phase_slope(cursor)=spectral.phase_slope(i,j);raw_trgc(cursor)=granger.raw_trgc(i,j);white_trgc(cursor)=granger.whitened_trgc(i,j);
            raw_tr_ok(cursor)=granger.raw_time_reversal_consistent(i,j);white_tr_ok(cursor)=granger.whitened_time_reversal_consistent(i,j);
            direction_agreement(cursor)=sign(raw_trgc(cursor))==sign(white_trgc(cursor))&&sign(raw_trgc(cursor))~=0;
        end,end
    catch ME
        qc_status(r)="ERROR";qc_message(r)=string(ME.identifier)+": "+string(ME.message);
    end
    fprintf('%d/%d %s %s %s\n',r,height(status),status.subject_id(r),status.condition(r),qc_status(r));
end

keep=1:cursor;edges=table(subject_id(keep),group(keep),condition(keep),rank_i(keep),rank_j(keep),patch_i(keep),patch_j(keep), ...
    coherence(keep),abs_imag(keep),wpli(keep),phase_slope(keep),raw_trgc(keep),white_trgc(keep),raw_tr_ok(keep),white_tr_ok(keep),direction_agreement(keep), ...
    'VariableNames',{'subject_id','group','condition','rank_i','rank_j','patch_i','patch_j','broadband_coherence', ...
    'absolute_imaginary_coherency','wPLI','phase_slope_i_relative_to_j','raw_time_reversal_Granger_score_i_to_j', ...
    'whitened_time_reversal_Granger_score_i_to_j','raw_time_reversal_consistent','whitened_time_reversal_consistent','raw_whitened_direction_agreement'});
qc=table(qc_subject,qc_group,qc_condition,qc_status,qc_message,qc_good,qc_original_fs,qc_analysis_fs,qc_samples, ...
    'VariableNames',{'subject_id','group','condition','status','message','n_good_epochs','original_fsample','analysis_fsample','analysis_samples_per_epoch'});
writetable(edges,fullfile(out,'A02_recording_pair_connectivity.csv'));writetable(qc,fullfile(out,'A02_connectivity_extraction_QC.csv'));
save(fullfile(out,'A02_patch_connectivity_results.mat'),'edges','qc','candidates','cfg','-v7.3');
fprintf('Wrote %d recording-pair rows from %d/%d recordings.\n',height(edges),sum(qc.status=="OK"),height(qc));
