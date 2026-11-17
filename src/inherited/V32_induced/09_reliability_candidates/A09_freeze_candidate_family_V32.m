%% Compute discovery-only reliability and freeze the confirmatory candidates.
clear; clc;
pipeline_root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pipeline_root,'lib'));
cfg=v32_setup();
out_root=fullfile(cfg.output_root,'09_reliability_candidates');
if ~exist(out_root,'dir'),mkdir(out_root);end
locked_mat=fullfile(out_root,'A09_candidate_family_LOCKED.mat');
if isfile(locked_mat)
    error('V32:CandidatesAlreadyFrozen','Candidate family already frozen: %s',locked_mat);
end

F=load(fullfile(cfg.output_root,'07_resolution_supports', ...
    'A07_frozen_resolution_supports_LOCKED.mat'),'frozen');
frozen=F.frozen; support_id=double(frozen.support_id);
n_supports=max(support_id); n_bands=numel(cfg.band_names);

split=readtable(fullfile(cfg.output_root,'05_frozen_split', ...
    'A05_participant_split_LABEL_BLIND.csv'),'Delimiter',',');
split.subject_id=string(split.subject_id); split.assignment=string(split.assignment);
discovery_ids=split.subject_id(split.assignment=="discovery");

status=readtable(fullfile(cfg.output_root,'02_epoch_energy', ...
    'A02_extraction_status.csv'),'Delimiter',',');
status.subject_id=string(status.subject_id); status.condition=string(status.condition);
status.output_file=string(status.output_file); status.status=string(status.status);
status=status(ismember(status.status,["OK","SKIPPED_EXISTS"]) & ...
    ismember(status.subject_id,discovery_ids),:);

n_rows=height(status)*n_bands*n_supports;
subject_id=strings(n_rows,1); condition=strings(n_rows,1); band=strings(n_rows,1);
support=zeros(n_rows,1); half1=nan(n_rows,1); half2=nan(n_rows,1);
full_percentile=nan(n_rows,1); posterior_precision=nan(n_rows,1);
cursor=0; audit=table();
for i=1:height(status)
    fprintf('Split half %d/%d: %s %s\n',i,height(status),status.subject_id(i),status.condition(i));
    state="OK";message="";
    try
        loaded=load(char(status.output_file(i)),'result'); r=loaded.result;
        D=spm_eeg_load(char(r.source_file));
        sh=v32_compute_split_half_supports(D,cfg,support_id);
        for b=1:n_bands
            for s=1:n_supports
                cursor=cursor+1; vertices=support_id==s;
                subject_id(cursor)=status.subject_id(i); condition(cursor)=status.condition(i);
                band(cursor)=string(cfg.band_names{b}); support(cursor)=s;
                half1(cursor)=sh.support_percentile(s,b,1);
                half2(cursor)=sh.support_percentile(s,b,2);
                full_percentile(cursor)=mean(double(r.percentile_log_mean_energy(vertices,b)),'omitnan');
                ratio=double(r.mean_energy(vertices,b))./(double(r.mean_energy(vertices,b))+ ...
                    double(r.posterior_variance(vertices,b))+eps);
                posterior_precision(cursor)=mean(ratio,'omitnan');
            end
        end
    catch ME
        state="FAILED"; message=regexprep(string(getReport(ME,'basic','hyperlinks','off')),'[\r\n]+',' | ');
    end
    row=table(status.subject_id(i),status.condition(i),state,message, ...
        'VariableNames',{'subject_id','condition','status','error_message'});
    audit=[audit;row]; %#ok<AGROW>
end
if any(audit.status=="FAILED")
    error('V32:ReliabilityFailure','%d split-half recordings failed.',sum(audit.status=="FAILED"));
end
metrics=table(subject_id,condition,band,support,half1,half2,full_percentile,posterior_precision, ...
    'VariableNames',{'subject_id','condition','band','support_id','half1_percentile', ...
    'half2_percentile','full_percentile','posterior_precision'});

reliability=table();
conditions=unique(metrics.condition);
for c=1:numel(conditions)
    for b=1:n_bands
        for s=1:n_supports
            rows=metrics.condition==conditions(c) & metrics.band==string(cfg.band_names{b}) & metrics.support_id==s;
            x=metrics.half1_percentile(rows); y=metrics.half2_percentile(rows);
            pearson=corr(x,y,'Rows','complete'); spearman=corr(x,y,'Type','Spearman','Rows','complete');
            sb=2*spearman/(1+spearman);
            row=table(conditions(c),string(cfg.band_names{b}),s,sum(rows),pearson,spearman,sb, ...
                mean(abs(x-y),'omitnan'),mean(metrics.full_percentile(rows)>=cfg.candidate_prevalence_percentile), ...
                median(metrics.posterior_precision(rows),'omitnan'), ...
                'VariableNames',{'condition','band','support_id','n_recordings','pearson_r', ...
                'spearman_r','spearman_brown','mean_absolute_half_difference','prevalence', ...
                'median_posterior_precision'});
            reliability=[reliability;row]; %#ok<AGROW>
        end
    end
end

separability=support_separability(frozen);
candidate=table();
for b=1:n_bands
    for s=1:n_supports
        rows=reliability.band==string(cfg.band_names{b}) & reliability.support_id==s;
        rel=max(0,min(1,mean(reliability.spearman_brown(rows),'omitnan')));
        prev=mean(reliability.prevalence(rows),'omitnan');
        prec=max(0,min(1,mean(reliability.median_posterior_precision(rows),'omitnan')));
        sep=separability(s);
        w=cfg.candidate_score_weights;
        score=w.reliability*rel+w.prevalence*prev+w.precision*prec+w.separability*sep;
        row=table(string(cfg.band_names{b}),s,rel,prev,prec,sep,score, ...
            'VariableNames',{'band','support_id','reliability_score','prevalence_score', ...
            'precision_score','separability_score','candidate_score'});
        candidate=[candidate;row]; %#ok<AGROW>
    end
end
candidate=sortrows(candidate,{'candidate_score','support_id'},{'descend','ascend'});
candidate.rank=(1:height(candidate))';
candidate.confirmatory=candidate.rank<=cfg.confirmatory_candidate_count;
confirmatory_family=candidate(candidate.confirmatory,:);

save(locked_mat,'confirmatory_family','candidate','reliability','metrics','audit','cfg','-v7.3');
writetable(audit,fullfile(out_root,'A09_split_half_processing_audit.csv'));
writetable(reliability,fullfile(out_root,'A09_split_half_reliability.csv'));
writetable(candidate,fullfile(out_root,'A09_candidate_scores_ALL.csv'));
writetable(confirmatory_family,fullfile(out_root,'A09_confirmatory_family_LOCKED.csv'));
fprintf('Frozen %d confirmatory support-band candidates from %d discovery recordings.\n', ...
    height(confirmatory_family),height(status));

function sep=support_separability(frozen)
initial=frozen.initial_component_id; final=frozen.support_id;
n_initial=size(frozen.mean_psf,1); n_supports=max(final); membership=zeros(n_initial,1);
for i=1:n_initial, membership(i)=mode(final(initial==i)); end
profiles=zeros(2*n_initial,n_supports);
for s=1:n_supports
    members=find(membership==s); w=frozen.initial_components.n_vertices(members); w=w/sum(w);
    profiles(:,s)=[frozen.mean_psf(:,members)*w;frozen.mean_ctf(:,members)*w];
end
profiles=profiles./max(vecnorm(profiles),eps); similarity=profiles'*profiles;
similarity(1:n_supports+1:end)=-Inf; sep=1-max(similarity,[],2); sep=max(0,min(1,sep));
end
