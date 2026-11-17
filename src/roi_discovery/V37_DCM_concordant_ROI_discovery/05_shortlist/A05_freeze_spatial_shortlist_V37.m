%% Freeze stable nonredundant spatial candidates for relationship analysis.
clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'lib'));
cfg = v37_setup();
out = fullfile(cfg.output_root, '05_shortlist');
if ~exist(out,'dir'), mkdir(out); end

R = load(fullfile(cfg.output_root,'04_supervised_discovery', ...
    'A04_nested_supervised_discovery.mat'),'result');
P = load(fullfile(cfg.output_root,'01_exact_IMG_patches', ...
    'A01_exact_SPM_IMG_patch_universe.mat'),'patches');
result = R.result; patches = P.patches;

T = table(result.patch_id,result.eligibility_count,result.selection_count, ...
    result.selection_frequency_when_eligible, ...
    result.mean_coefficient_magnitude_when_eligible, ...
    'VariableNames',{'patch_id','eligible_outer_folds','selected_outer_folds', ...
    'selection_frequency','mean_coefficient_magnitude'});
T = T(T.selection_frequency >= cfg.minimum_outer_selection_frequency,:);
T = sortrows(T,{'selection_frequency','mean_coefficient_magnitude'}, ...
    {'descend','descend'});

kept = zeros(0,1); representative = zeros(height(T),1);
reason = strings(height(T),1); retained = false(height(T),1);
xyz = [patches.patch_table.x,patches.patch_table.y,patches.patch_table.z];
for i = 1:height(T)
    p = T.patch_id(i);
    conflict = 0; why = "";
    for j = 1:numel(kept)
        q = kept(j);
        d = norm(xyz(p,:)-xyz(q,:));
        c = double(patches.rms_canonical_correlation(p,q));
        if d < cfg.redundancy_coordinate_distance_mm
            conflict = q; why = "coordinate distance < technical redundancy threshold"; break
        elseif c >= cfg.redundancy_subspace_rms_correlation
            conflict = q; why = "regional lead-field subspace ambiguity"; break
        end
    end
    if conflict == 0 && numel(kept) < cfg.shortlist_max_nodes
        kept(end+1,1) = p; %#ok<AGROW>
        retained(i) = true; representative(i) = p; reason(i) = "retained";
    elseif conflict > 0
        representative(i) = conflict; reason(i) = why;
    else
        reason(i) = "shortlist capacity reached";
    end
end
T.retained_for_relationship_screen = retained;
T.representative_patch_id = representative;
T.redundancy_decision = reason;
writetable(T,fullfile(out,'A05_all_stable_patch_decisions.csv'));

shortlist = T(T.retained_for_relationship_screen,:);
if ~isempty(shortlist)
    [~,loc] = ismember(shortlist.patch_id,patches.patch_table.patch_id);
    annotation = patches.patch_table(loc,:);
    shortlist = [shortlist,annotation(:,setdiff(annotation.Properties.VariableNames, ...
        {'patch_id'},'stable'))];
    shortlist.shortlist_rank = (1:height(shortlist))';
    shortlist = movevars(shortlist,'shortlist_rank','Before',1);
end
writetable(shortlist,fullfile(out,'A05_frozen_spatial_shortlist.csv'));
audit = struct('shortlist',shortlist,'all_decisions',T, ...
    'uses_age_or_sex_for_selection',false, ...
    'uses_V34_candidate_rank',false, ...
    'uses_activity_percentile_gate',false, ...
    'validation_participants_read',0, ...
    'redundancy_rule', ...
    "collapse only after supervised stability using exact IMG subspace or physical proximity");
save(fullfile(out,'A05_frozen_spatial_shortlist.mat'),'audit','cfg','-v7.3');
fprintf('Froze %d nonredundant nodes from %d stability-qualified patches.\n', ...
    height(shortlist),height(T));
