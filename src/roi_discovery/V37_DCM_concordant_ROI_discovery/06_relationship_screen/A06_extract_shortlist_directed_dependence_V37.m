%% Extract shortlist-only dependence metrics; these are not causal estimates.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'lib'));
cfg = v37_setup();
out = fullfile(cfg.output_root,'06_relationship_screen');
if ~exist(out,'dir'), mkdir(out); end
P = load(fullfile(cfg.output_root,'01_exact_IMG_patches', ...
    'A01_exact_SPM_IMG_patch_universe.mat'),'patches');
patches = P.patches;
nodes = readtable(fullfile(cfg.output_root,'05_shortlist', ...
    'A05_frozen_spatial_shortlist.csv'),'Delimiter',',');
if height(nodes) < 2, error('V37:Shortlist','At least two shortlisted nodes are required.'); end
patch_ids = nodes.patch_id; nnode = numel(patch_ids);
status = v37_discovery_recordings(cfg); npair = nchoosek(nnode,2);
nmax = height(status)*npair; cursor = 0;
subject_id = strings(nmax,1); group = strings(nmax,1); condition = strings(nmax,1);
patch_i = zeros(nmax,1); patch_j = zeros(nmax,1);
coherence = nan(nmax,1); abs_imag = nan(nmax,1); wpli = nan(nmax,1);
phase_slope = nan(nmax,1); raw_trgc = nan(nmax,1); white_trgc = nan(nmax,1);
raw_tr_ok = false(nmax,1); white_tr_ok = false(nmax,1);
qc = status(:,{'subject_id','group','condition'}); qc.status = repmat("PENDING",height(status),1);
qc.message = strings(height(status),1);

for r = 1:height(status)
    try
        D = spm_eeg_load(char(status.source_file(r)));
        region = v37_exact_img_filters(D,cfg,patches);
        mode_rows = reshape(1:size(region.filters,1),cfg.regional_spatial_modes,[])';
        node_filters = zeros(nnode,size(region.filters,2));
        for i = 1:nnode
            F = region.filters(mode_rows(patch_ids(i),:),:);
            [u,~,~] = svd(F,'econ'); w = u(:,1);
            [~,anchor] = max(abs(w)); if w(anchor)<0, w=-w; end
            node_filters(i,:) = w'*F;
        end
        node = struct('filters',node_filters,'inverse',region.inverse);
        [epochs,fs,~] = v35_extract_epochs(D,cfg,node);
        sm = v35_connectivity_metrics(epochs,fs,cfg);
        gm = v35_granger_sensitivity(epochs,cfg);
        qc.status(r) = "OK";
        for i = 1:nnode
            for j = i+1:nnode
                cursor=cursor+1; subject_id(cursor)=status.subject_id(r);
                group(cursor)=status.group(r); condition(cursor)=status.condition(r);
                patch_i(cursor)=patch_ids(i); patch_j(cursor)=patch_ids(j);
                coherence(cursor)=sm.coherence(i,j);
                abs_imag(cursor)=sm.abs_imaginary_coherency(i,j);
                wpli(cursor)=sm.wpli(i,j); phase_slope(cursor)=sm.phase_slope(i,j);
                raw_trgc(cursor)=gm.raw_trgc(i,j); white_trgc(cursor)=gm.whitened_trgc(i,j);
                raw_tr_ok(cursor)=gm.raw_time_reversal_consistent(i,j);
                white_tr_ok(cursor)=gm.whitened_time_reversal_consistent(i,j);
            end
        end
    catch ME
        qc.status(r)="ERROR"; qc.message(r)=string(ME.identifier)+": "+string(ME.message);
    end
    writetable(qc,fullfile(out,'A06_relationship_extraction_QC.csv'));
    fprintf('%d/%d %s %s %s\n',r,height(status),status.subject_id(r), ...
        status.condition(r),qc.status(r));
end
k = 1:cursor;
edges = table(subject_id(k),group(k),condition(k),patch_i(k),patch_j(k), ...
    coherence(k),abs_imag(k),wpli(k),phase_slope(k),raw_trgc(k),white_trgc(k), ...
    raw_tr_ok(k),white_tr_ok(k), ...
    'VariableNames',{'subject_id','group','condition','patch_i','patch_j', ...
    'broadband_coherence','absolute_imaginary_coherency','wPLI', ...
    'phase_slope_i_relative_to_j','raw_time_reversal_Granger_score_i_to_j', ...
    'whitened_time_reversal_Granger_score_i_to_j', ...
    'raw_time_reversal_consistent','whitened_time_reversal_consistent'});
writetable(edges,fullfile(out,'A06_shortlist_directed_dependence_NOT_CAUSAL.csv'));
save(fullfile(out,'A06_shortlist_directed_dependence_NOT_CAUSAL.mat'), ...
    'edges','qc','nodes','cfg','-v7.3');
