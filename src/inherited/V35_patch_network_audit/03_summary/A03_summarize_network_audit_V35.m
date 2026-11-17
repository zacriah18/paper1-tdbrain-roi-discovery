%% Summarize network metrics without using them for node selection.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v35_setup();
out=fullfile(cfg.output_root,'03_summary');if ~exist(out,'dir'),mkdir(out);end
E=readtable(fullfile(cfg.output_root,'02_connectivity','A02_recording_pair_connectivity.csv'),'Delimiter',',');
for v={'subject_id','group','condition'},E.(v{1})=string(E.(v{1}));end
metrics={'broadband_coherence','absolute_imaginary_coherency','wPLI','phase_slope_i_relative_to_j', ...
    'raw_time_reversal_Granger_score_i_to_j','whitened_time_reversal_Granger_score_i_to_j'};
pairs=unique(E(:,{'rank_i','rank_j','patch_i','patch_j'}),'rows');group_effects=table();direction=table();
for p=1:height(pairs)
    rows=E.rank_i==pairs.rank_i(p)&E.rank_j==pairs.rank_j(p);R=E(rows,:);ids=unique(R.subject_id);
    values=nan(numel(ids),numel(metrics));diagnosis=strings(numel(ids),1);
    for s=1:numel(ids)
        q=R.subject_id==ids(s);diagnosis(s)=R.group(find(q,1));
        for m=1:numel(metrics),values(s,m)=mean(R.(metrics{m})(q),'omitnan');end
    end
    for m=1:numel(metrics)
        a=values(diagnosis=="MDD",m);b=values(diagnosis=="HC",m);d=cohen(a,b);auc=empirical_auc(a,b);
        row=table(pairs.rank_i(p),pairs.rank_j(p),pairs.patch_i(p),pairs.patch_j(p),string(metrics{m}), ...
            numel(a),numel(b),mean(a,'omitnan'),mean(b,'omitnan'),d,auc,max(auc,1-auc),false, ...
            'VariableNames',{'rank_i','rank_j','patch_i','patch_j','metric','n_MDD','n_HC','mean_MDD','mean_HC', ...
            'descriptive_cohen_d','descriptive_AUC_MDD_high','orientation_free_AUC','used_for_node_selection'});group_effects=[group_effects;row]; %#ok<AGROW>
    end
    raw=R.raw_time_reversal_Granger_score_i_to_j;white=R.whitened_time_reversal_Granger_score_i_to_j;
    raw_sign=max(mean(raw>0),mean(raw<0));white_sign=max(mean(white>0),mean(white<0));
    joint=mean(R.raw_time_reversal_consistent&R.whitened_time_reversal_consistent&R.raw_whitened_direction_agreement);
    row=table(pairs.rank_i(p),pairs.rank_j(p),pairs.patch_i(p),pairs.patch_j(p),height(R), ...
        median(abs(R.raw_time_reversal_Granger_score_i_to_j),'omitnan'),median(abs(R.whitened_time_reversal_Granger_score_i_to_j),'omitnan'), ...
        mean(R.raw_time_reversal_consistent),mean(R.whitened_time_reversal_consistent),mean(R.raw_whitened_direction_agreement),raw_sign,white_sign,joint, ...
        median(R.phase_slope_i_relative_to_j,'omitnan'), ...
        'VariableNames',{'rank_i','rank_j','patch_i','patch_j','n_recordings','median_absolute_raw_TRGC', ...
        'median_absolute_whitened_TRGC','raw_time_reversal_consistency','whitened_time_reversal_consistency', ...
        'raw_whitened_direction_agreement','raw_population_sign_consistency','whitened_population_sign_consistency', ...
        'joint_time_reversal_whitening_pass_rate','median_phase_slope_i_relative_to_j'});direction=[direction;row]; %#ok<AGROW>
end
writetable(group_effects,fullfile(out,'A03_connectivity_MDD_HC_description_NOT_SELECTION.csv'));
writetable(direction,fullfile(out,'A03_directionality_sensitivity_by_pair.csv'));

I=readtable(fullfile(cfg.output_root,'01_identifiability','A01_pairwise_patch_identifiability.csv'),'Delimiter',',');
joined=outerjoin(I,direction,'Keys',{'rank_i','rank_j','patch_i','patch_j'},'MergeKeys',true,'Type','left');
writetable(joined,fullfile(out,'A03_integrated_identifiability_directionality_audit.csv'));
save(fullfile(out,'A03_network_audit_summary.mat'),'group_effects','direction','joined','cfg','-v7.3');

[~,ix]=sort(abs(group_effects.descriptive_cohen_d),'descend');top=group_effects(ix(1:min(10,height(group_effects))),:);
fid=fopen(fullfile(out,'A03_NETWORK_INTERPRETATION.md'),'w');
fprintf(fid,'# V35 network interpretation\n\n');
fprintf(fid,'The 12-node network was evaluated on %d discovery recordings. Connectivity and class-description metrics were not used for node selection.\n\n',height(unique(E(:,{'subject_id','condition'}),'rows')));
fprintf(fid,'## Defensible statements\n\n');
fprintf(fid,'- The identifiability table determines which node pairs can reasonably receive separate source-level interpretations.\n');
fprintf(fid,'- Coherence, absolute imaginary coherency, and wPLI describe statistical dependence in reconstructed virtual-node signals.\n');
fprintf(fid,'- A Granger direction is only a sensitivity signal when it survives time reversal and retains its sign after instantaneous whitening. It is not evidence of biological causality.\n');
fprintf(fid,'- The largest unadjusted class descriptions are listed for model-design context only; they are not inferential findings or selection criteria.\n\n');
fprintf(fid,'## Ten largest absolute descriptive MDD/HC effects across edge metrics\n\n');
fprintf(fid,'| Nodes | Metric | Cohen d | Orientation-free AUC |\n|---|---|---:|---:|\n');
for i=1:height(top),fprintf(fid,'| %d-%d | %s | %.3f | %.3f |\n',top.rank_i(i),top.rank_j(i),top.metric(i),top.descriptive_cohen_d(i),top.orientation_free_AUC(i));end
fprintf(fid,'\nThese values require shrinkage or multiple-comparison control and held-out confirmation before any group claim. The next effective-connectivity step is a small, anatomically constrained cross-spectral DCM model space, not selection of edges from these same data.\n');fclose(fid);

function d=cohen(a,b)
a=a(isfinite(a));b=b(isfinite(b));d=(mean(a)-mean(b))/(sqrt(((numel(a)-1)*var(a)+(numel(b)-1)*var(b))/max(numel(a)+numel(b)-2,1))+eps);
end
function auc=empirical_auc(a,b)
a=a(isfinite(a));b=b(isfinite(b));x=[a(:);b(:)];r=tiedrank(x);auc=(sum(r(1:numel(a)))-numel(a)*(numel(a)+1)/2)/(numel(a)*numel(b));
end
