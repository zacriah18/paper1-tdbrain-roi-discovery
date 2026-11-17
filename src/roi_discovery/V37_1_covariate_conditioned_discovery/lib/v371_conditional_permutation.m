function [yp,meta] = v371_conditional_permutation(y,P,seed,outer_fold)
%V371_CONDITIONAL_PERMUTATION Shuffle diagnosis inside locked nuisance blocks.
% Blocks: age band x sex x recording-condition availability. A candidate is
% accepted only when every locked outer train and test split retains both
% diagnosis classes.
y = double(y(:));
[~,~,sex_binary] = v371_nuisance_matrix(P);
key = string(P.age_band) + "|sex=" + string(sex_binary) + ...
    "|condition=" + string(P.condition_availability);
[block_name,~,block_id] = unique(key,'stable');

accepted = false; attempt = 0;
while ~accepted && attempt < 1000
    attempt = attempt + 1;
    stream = RandStream('mt19937ar','Seed',seed + attempt - 1);
    yp = y;
    for b = 1:numel(block_name)
        idx = find(block_id==b);
        if numel(idx)>1
            yp(idx) = y(idx(randperm(stream,numel(idx))));
        end
    end
    accepted = local_valid_locked_folds(yp,outer_fold);
end
if ~accepted
    error('V371:PermutationFailure', ...
        'Could not generate a class-valid conditional permutation in 1000 attempts.');
end
meta = struct('seed',seed,'attempts',attempt,'block_name',block_name, ...
    'block_id',block_id,'n_blocks',numel(block_name));
end

function tf = local_valid_locked_folds(y,outer_fold)
tf = true;
for r = 1:size(outer_fold,2)
    for o = unique(outer_fold(:,r))'
        test = outer_fold(:,r)==o;
        if numel(unique(y(test)))<2 || numel(unique(y(~test)))<2
            tf = false; return;
        end
    end
end
end
