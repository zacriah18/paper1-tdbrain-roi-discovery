function [model, inverse, val] = v32_get_inverse(D, requested_val)
%V32_GET_INVERSE Resolve and validate the requested SPM inverse model.

if nargin < 2 || isempty(requested_val)
    try
        val = D.val;
    catch
        val = 1;
    end
else
    val = requested_val;
end

try
    model = D.inv{val};
catch
    error('V32:MissingInverse', 'D.inv{%d} is not available.', val);
end
if isempty(model) || ~isfield(model, 'inverse') || isempty(model.inverse)
    error('V32:MissingInverse', 'D.inv{%d}.inverse is missing.', val);
end
inverse = model.inverse;

required = {'M','L','T','U','Ic','It','qC','qV'};
for i = 1:numel(required)
    if ~isfield(inverse, required{i}) || isempty(inverse.(required{i}))
        error('V32:MissingField', 'inverse.%s is missing.', required{i});
    end
end
end
