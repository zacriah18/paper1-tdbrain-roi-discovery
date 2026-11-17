%% Freeze identical outer and inner participant folds for all V37.1 models.
clear; clc;
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'lib'));
cfg=v371_setup(); out=fullfile(cfg.output_root,'01_folds');
if ~exist(out,'dir'),mkdir(out);end
D=load(fullfile(cfg.project_root,'derivatives','V37_DCM_concordant_ROI_discovery', ...
    '03_participant_features','A03_participant_spectral_landscapes.mat'),'dataset');
dataset=D.dataset; P=dataset.participants;
if height(P)~=cfg.expected_discovery_participants || any(string(P.assignment)~="discovery")
    error('V371:ValidationBoundary','Expected exactly 225 discovery participants.');
end
y=double(string(P.group)=="MDD"); n=height(P);
outer_fold=zeros(n,cfg.outer_repeats); inner_fold=cell(cfg.outer_repeats,cfg.outer_folds);
for r=1:cfg.outer_repeats
    outer_fold(:,r)=v37_make_folds(y,P.sex,P.age_band,cfg.outer_folds, ...
        cfg.random_seed+1000*r);
    for o=1:cfg.outer_folds
        train=find(outer_fold(:,r)~=o);
        inner_fold{r,o}=v37_make_folds(y(train),P.sex(train),P.age_band(train), ...
            cfg.inner_folds,cfg.random_seed+1000*r+o);
    end
end
manifest=table(P.subject_id,P.group,P.age,P.sex,P.age_band,P.condition_availability, ...
    'VariableNames',{'subject_id','group','age','sex','age_band','condition_availability'});
for r=1:cfg.outer_repeats,manifest.(sprintf('repeat_%d_outer_fold',r))=outer_fold(:,r);end
writetable(manifest,fullfile(out,'A01_locked_outer_folds.csv'));
folds=struct('subject_id',string(P.subject_id),'y',y,'outer_fold',outer_fold, ...
    'inner_fold',{inner_fold},'random_seed',cfg.random_seed, ...
    'validation_participants_read',0);
save(fullfile(out,'A01_locked_nested_folds.mat'),'folds','cfg','-v7.3');
fprintf('Locked %d repeats x %d outer folds for %d discovery participants; validation read=0.\n', ...
    cfg.outer_repeats,cfg.outer_folds,n);
