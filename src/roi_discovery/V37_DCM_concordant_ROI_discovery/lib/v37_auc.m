function auc = v37_auc(y, score)
%V37_AUC Mann-Whitney AUC with explicit tie handling.
y = logical(y(:)); score = double(score(:));
ok = isfinite(score); y = y(ok); score = score(ok);
n1 = sum(y); n0 = sum(~y);
if n1 == 0 || n0 == 0, auc = NaN; return; end
[s, order] = sort(score); ranks = zeros(size(s));
i = 1;
while i <= numel(s)
    j = i;
    while j < numel(s) && s(j+1) == s(i), j = j+1; end
    ranks(i:j) = (i+j)/2; i = j+1;
end
unsorted = zeros(size(ranks)); unsorted(order) = ranks;
auc = (sum(unsorted(y)) - n1*(n1+1)/2)/(n1*n0);
end
