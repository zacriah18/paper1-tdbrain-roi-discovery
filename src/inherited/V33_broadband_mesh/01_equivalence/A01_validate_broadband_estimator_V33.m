%% Validate coefficient-domain energy against explicit reconstructed time series.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v33_setup();
out=fullfile(cfg.output_root,'01_equivalence');if ~exist(out,'dir'),mkdir(out);end
inv=readtable(cfg.inventory_csv,'Delimiter',',','VariableNamingRule','preserve');
inv.subject_id=string(inv.subject_id);inv.condition=string(inv.condition);inv.source_file=string(inv.source_file);
row=inv(inv.subject_id=="sub-87958013"&inv.condition=="restEC",:);row=row(1,:);
D=spm_eeg_load(char(row.source_file));result=v33_compute_broadband_energy(D,cfg);
[~,inverse]=v32_get_inverse(D,cfg.inverse_index);T=double(inverse.T);U=inverse.U;Ic=inverse.Ic;
if ~iscell(U),U={U};end;if ~iscell(Ic),Ic={Ic};end
try,scale=inverse.scale;catch,scale=1;end;if numel(scale)>1,scale=scale(1);end
explicit=zeros(size(inverse.M,1),1);
for j=1:numel(result.good_trial_indices)
    raw=double(D(Ic{1},inverse.It,result.good_trial_indices(j)));
    coefficients=double(inverse.M)*(double(U{1})*(raw*T)*double(scale));
    source_time=coefficients*T';
    explicit=explicit+mean(source_time.^2,2);
end
explicit=explicit/numel(result.good_trial_indices);observed=double(result.mean_broadband_energy);
delta=observed-explicit;max_abs=max(abs(delta));max_rel=max(abs(delta)./max(abs(explicit),eps));
pearson_r=corr(observed,explicit);pass=max_abs<=cfg.broadband_equivalence_abs_tolerance|| ...
    (max_rel<=cfg.broadband_equivalence_rel_tolerance&&pearson_r>1-1e-12);
equivalence=table(row.subject_id,row.condition,result.n_good_trials,result.n_temporal_modes, ...
    result.temporal_orthogonality_error,max_abs,max_rel,pearson_r,pass, ...
    'VariableNames',{'subject_id','condition','n_trials','n_temporal_modes', ...
    'orthogonality_error','max_abs_error','max_relative_error','pearson_r','pass'});
writetable(equivalence,fullfile(out,'A01_broadband_equivalence.csv'));
save(fullfile(out,'A01_broadband_equivalence.mat'),'equivalence','cfg');
if ~pass,error('V33 broadband equivalence failed.');end
fprintf('Broadband equivalence passed: max rel %.3g, r %.15f.\n',max_rel,pearson_r);
