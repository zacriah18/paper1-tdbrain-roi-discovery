function [Z,names,sex_binary] = v371_nuisance_matrix(P)
%V371_NUISANCE_MATRIX Numeric nuisance design with robust 0/1 sex coding.
age = double(P.age(:));
sex_text = upper(strtrim(string(P.sex(:))));
sex_numeric = str2double(sex_text);
if all(isfinite(sex_numeric))
    sex_binary = sex_numeric;
else
    categories = unique(sex_text(~ismissing(sex_text)),'stable');
    if numel(categories)~=2
        error('V371:SexCoding','Expected two observable sex categories.');
    end
    sex_binary = double(sex_text==categories(2));
end
paired = double(string(P.condition_availability(:))=="paired_EC_EO");
Z = [age,(age-45).^2,sex_binary,paired];
names = {'age','age_squared','sex_binary','paired_condition_available'};
end
