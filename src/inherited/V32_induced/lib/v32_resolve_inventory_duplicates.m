function [selected, audit] = v32_resolve_inventory_duplicates(inventory, cfg)
% Resolve participant-condition duplicates only through explicit overrides.

key = inventory.subject_id + "|" + inventory.group + "|" + inventory.condition;
unique_keys = unique(key, 'stable');
keep = true(height(inventory),1);
audit = table();

for i = 1:numel(unique_keys)
    rows = find(key == unique_keys(i));
    if numel(rows) == 1
        continue;
    end

    first = rows(1);
    overrides = cfg.inventory_duplicate_overrides;
    match = overrides.subject_id == inventory.subject_id(first) & ...
        overrides.group == inventory.group(first) & ...
        overrides.condition == inventory.condition(first);
    if sum(match) ~= 1
        error('V32:UnresolvedDuplicate', ...
            'Duplicate inventory key %s requires exactly one explicit override.', ...
            unique_keys(i));
    end

    preferred = overrides.preferred_basename(match);
    rationale = overrides.rationale(match);
    basenames = strings(numel(rows),1);
    for j = 1:numel(rows)
        [~, name, ext] = fileparts(char(inventory.source_file(rows(j))));
        basenames(j) = string([name ext]);
    end
    chosen_local = find(basenames == preferred);
    if numel(chosen_local) ~= 1
        error('V32:DuplicateOverrideMismatch', ...
            'Preferred file %s was not found uniquely for %s.', preferred, unique_keys(i));
    end
    chosen_row = rows(chosen_local);
    keep(rows) = false;
    keep(chosen_row) = true;

    for j = 1:numel(rows)
        a = table(inventory.subject_id(rows(j)), inventory.group(rows(j)), ...
            inventory.condition(rows(j)), inventory.source_file(rows(j)), ...
            rows(j) == chosen_row, rationale, ...
            'VariableNames', {'subject_id','group','condition','source_file', ...
            'selected','rationale'});
        audit = [audit; a]; %#ok<AGROW>
    end
end

selected = inventory(keep,:);
end
