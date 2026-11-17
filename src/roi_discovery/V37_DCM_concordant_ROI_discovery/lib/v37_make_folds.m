function fold = v37_make_folds(y, sex, age_band, k, seed)
%V37_MAKE_FOLDS Participant folds balanced on label, sex and age band.
rng(seed, 'twister');
y = double(y(:)); sex = string(sex(:)); age_band = string(age_band(:));
stratum = string(y) + "|" + sex + "|" + age_band;
fold = zeros(numel(y),1);
u = unique(stratum);
for s = 1:numel(u)
    idx = find(stratum == u(s));
    idx = idx(randperm(numel(idx)));
    labels = repmat((1:k)',ceil(numel(idx)/k),1);
    labels = labels(1:numel(idx));
    labels = circshift(labels, mod(s-1,k));
    fold(idx) = labels;
end
% Empty folds can occur only with extremely small smoke datasets.
if any(fold == 0), error('V37:Folds', 'Fold construction failed.'); end
end
