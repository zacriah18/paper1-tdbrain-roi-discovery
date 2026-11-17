%% Diagnose recordings excluded by the V35 connectivity variance check.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v35_setup();
out=fullfile(cfg.output_root,'02_connectivity');
qc=readtable(fullfile(out,'A02_connectivity_extraction_QC.csv'),'Delimiter',',');
for v={'subject_id','condition','status','message'},qc.(v{1})=string(qc.(v{1}));end
bad=qc(qc.status=="ERROR",:);status=v35_discovery_recordings(cfg);
P=load(fullfile(cfg.project_root,'derivatives','V34_DCM_aligned_patches', ...
    '01_patch_tiling','A01_DCM_aligned_16mm_patches.mat'),'patches');
C=load(fullfile(cfg.project_root,'derivatives','V34_DCM_aligned_patches', ...
    '03_candidates','A03_DCM_aligned_candidate_results.mat'),'candidates');C.candidates=sortrows(C.candidates,'candidate_rank');
result=table();
for b=1:height(bad)
    r=find(status.subject_id==bad.subject_id(b)&status.condition==bad.condition(b),1);
    D=spm_eeg_load(char(status.source_file(r)));node=v35_node_operator(D,cfg,P.patches,C.candidates.patch_id);
    [epochs,fs,good]=v35_extract_epochs(D,cfg,node);sd=cell2mat(cellfun(@(x)std(x,0,2),epochs,'UniformOutput',false)');
    for i=1:height(C.candidates)
        row=table(bad.subject_id(b),bad.condition(b),C.candidates.candidate_rank(i),C.candidates.patch_id(i), ...
            numel(good),fs,size(epochs{1},2),norm(node.filters(i,:)),min(sd(i,:)),median(sd(i,:)),max(sd(i,:)),sum(sd(i,:)<=eps), ...
            'VariableNames',{'subject_id','condition','candidate_rank','patch_id','n_good_epochs','analysis_fsample', ...
            'analysis_samples_per_epoch','filter_norm','minimum_epoch_sd','median_epoch_sd','maximum_epoch_sd','epochs_at_or_below_eps'});result=[result;row]; %#ok<AGROW>
    end
end
writetable(result,fullfile(out,'A02b_excluded_recording_node_variance_diagnostics.csv'));
for b=1:height(bad)
    q=result.subject_id==bad.subject_id(b)&result.condition==bad.condition(b);first=find(q,1);
    loc=find(qc.subject_id==bad.subject_id(b)&qc.condition==bad.condition(b),1);
    qc.n_good_epochs(loc)=result.n_good_epochs(first);qc.analysis_fsample(loc)=result.analysis_fsample(first);
    qc.analysis_samples_per_epoch(loc)=result.analysis_samples_per_epoch(first);
    zero_ranks=result.candidate_rank(q&result.epochs_at_or_below_eps==result.n_good_epochs);
    qc.message(loc)="V35:ZeroInversePatch: all epochs have zero variance for candidate rank(s) "+join(string(zero_ranks),",")+"; excluded from complete 12-node virtual-signal audit";
end
writetable(qc,fullfile(out,'A02_connectivity_extraction_QC.csv'));
disp(result);
