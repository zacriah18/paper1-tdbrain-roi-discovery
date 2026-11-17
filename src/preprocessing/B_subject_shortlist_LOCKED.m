%% =========================================================================
% B_subject_shortlist_FORMAL_STATUS_ALL_SESSIONS_V31.m
%
% V3.1-native shortlist/copy step for TDBRAIN resting-state BDF data.
%
% Input:
%   derivatives\A_inventory_V31\TDBRAIN_V31_rest_inventory_EC_EO.csv
%
% Selects formally diagnosed MDD and formally HEALTHY/HC/control subjects,
% across all available sessions, requiring paired restEC and restEO BDF files
% within the same subject/session.
%
% Outputs are intentionally compatible with existing downstream naming:
%   TDBRAIN_subject_shortlist_LOCKED_subjects.csv
%   TDBRAIN_subject_shortlist_LOCKED_rows_EC_EO.csv
%
% V3.1 file set per row:
%   - bdf_path
%   - json_path
%   - channels_path
%
% Notes:
%   - No BrainVision .vhdr/.eeg/.vmrk files are required or created.
%   - C_import must consume bdf_path rather than vhdr_path.
% =========================================================================

clear; clc;
diary off;

%% Paths
rootDir = 'C:\MATLAB\2026 TDBRAIN dataset';

inFile = fullfile(rootDir, ...
    'derivatives', ...
    'A_inventory_V31', ...
    'TDBRAIN_V31_rest_inventory_EC_EO.csv');

outDir = fullfile(rootDir, ...
    'derivatives', ...
    'B_subject_shortlist_FORMAL_STATUS_ALL_SESSIONS');

lockedDataDir = fullfile(outDir, 'locked_input_files');

if ~exist(outDir, 'dir'), mkdir(outDir); end
if ~exist(lockedDataDir, 'dir'), mkdir(lockedDataDir); end

logFile = fullfile(outDir, 'B_subject_shortlist_FORMAL_STATUS_ALL_SESSIONS_log.txt');
if exist(logFile, 'file')
    try
        delete(logFile);
    catch
        warning('Could not delete old log file. Continuing and overwriting/appending diary if MATLAB allows it.');
    end
end
diary(logFile);

fprintf('\n====================================================\n');
fprintf('B_subject_shortlist_FORMAL_STATUS_ALL_SESSIONS_V31 started\n');
fprintf('Input:  %s\n', inFile);
fprintf('Output: %s\n', outDir);
fprintf('====================================================\n\n');

if ~exist(inFile, 'file')
    error('Input inventory not found: %s', inFile);
end

T = readtable(inFile, 'VariableNamingRule', 'preserve');
fprintf('Loaded inventory rows: %d\n', height(T));
fprintf('Loaded inventory columns: %d\n', width(T));

%% Required fields from A_inventory_V31
requiredVars = {'subject_id','task','session','session_key', ...
    'bdf_path','json_path','channels_path','formal_status'};

for r = 1:numel(requiredVars)
    if ~any(strcmp(T.Properties.VariableNames, requiredVars{r}))
        error('Required column missing from V31 inventory: %s', requiredVars{r});
    end
end

T.subject_id    = string(T.subject_id);
T.task          = string(T.task);
T.session       = string(T.session);
T.bdf_path      = string(T.bdf_path);
T.json_path     = string(T.json_path);
T.channels_path = string(T.channels_path);
T.formal_status = upper(strtrim(string(T.formal_status)));

% Ensure session is BIDS-style text even if readtable changed types.
if all(strlength(strtrim(T.session)) == 0 | ismissing(T.session))
    T.session = "ses-" + string(T.session_key);
end

%% Adult / usable flags
if any(strcmp(T.Properties.VariableNames, 'is_adult'))
    T.is_adult_final = logical(T.is_adult);
else
    ageVec = parseNumericColumn(getOptionalColumn(T, {'age_num','age'}));
    if all(isnan(ageVec))
        warning('No age/adult metadata found. Adult filter cannot be applied; retaining all ages.');
        T.is_adult_final = true(height(T),1);
    else
        T.is_adult_final = ageVec >= 18;
    end
end

if any(strcmp(T.Properties.VariableNames, 'usable_resting'))
    T.usable_final = logical(T.usable_resting);
elseif any(strcmp(T.Properties.VariableNames, 'has_all_files'))
    T.usable_final = logical(T.has_all_files);
else
    T.usable_final = true(height(T),1);
end

%% V3.1 complete-file check
T.complete_file_set = false(height(T),1);
for i = 1:height(T)
    T.complete_file_set(i) = isfile(T.bdf_path(i)) && ...
                             isfile(T.json_path(i)) && ...
                             isfile(T.channels_path(i));
end

fprintf('\nFile-set check:\n');
fprintf('  Complete BDF/json/channels rows: %d\n', sum(T.complete_file_set));
fprintf('  Incomplete rows: %d\n', sum(~T.complete_file_set));

%% Base row filter: formal MDD/HEALTHY, adult, restEC/restEO, complete files
status = T.formal_status;
isFormalHealthy = status == "HEALTHY" | status == "HC" | status == "CONTROL";
isFormalMDD     = status == "MDD";
isRestTask      = T.task == "restEC" | T.task == "restEO";

baseMask = T.is_adult_final & T.usable_final & T.complete_file_set & ...
           isRestTask & (isFormalHealthy | isFormalMDD);

Tbase = T(baseMask, :);

fprintf('\nBase formal-status all-session rows: %d\n', height(Tbase));
fprintf('  HEALTHY rows: %d\n', sum(Tbase.formal_status == "HEALTHY" | Tbase.formal_status == "HC" | Tbase.formal_status == "CONTROL"));
fprintf('  MDD rows:     %d\n', sum(Tbase.formal_status == "MDD"));
fprintf('  restEC rows:  %d\n', sum(Tbase.task == "restEC"));
fprintf('  restEO rows:  %d\n', sum(Tbase.task == "restEO"));

if height(Tbase) == 0
    error('No rows survived formal-status all-session filtering. Check formal_status/session/task/path columns.');
end

%% Build session-level table: require paired EC+EO within subject/session
keys = unique(strcat(Tbase.subject_id, "__", Tbase.session), 'stable');
Sessions = table();

for k = 1:numel(keys)
    parts = split(keys(k), "__");
    sid = parts(1);
    ses = parts(2);

    R = Tbase(Tbase.subject_id == sid & Tbase.session == ses, :);
    if isempty(R), continue; end

    hasEC = any(R.task == "restEC");
    hasEO = any(R.task == "restEO");

    if ~(hasEC && hasEO)
        continue;
    end

    row = R(1,:);

    srow = table();
    srow.subject_id = sid;
    srow.session = ses;

    st = row.formal_status;
    if st == "MDD"
        srow.group = "MDD";
        srow.group_code = 1;
    else
        srow.group = "HC";
        srow.group_code = 0;
    end

    srow.formal_status = string(row.formal_status);
    srow.has_restEC = true;
    srow.has_restEO = true;
    srow.has_both_EC_EO = true;
    srow.n_condition_rows = height(R);
    srow.n_restEC_rows = sum(R.task == "restEC");
    srow.n_restEO_rows = sum(R.task == "restEO");

    srow.age = parseOneNumeric(row, {'age_num','age'});
    srow.gender = parseOneNumeric(row, {'gender'});
    srow.education = parseOneNumeric(row, {'education'});

    if any(strcmp(row.Properties.VariableNames, 'DISC/REP'))
        srow.discovery_replication = string(row.('DISC/REP'));
    else
        srow.discovery_replication = "";
    end

    if any(strcmp(row.Properties.VariableNames, 'indication'))
        srow.indication = string(row.indication);
    else
        srow.indication = "";
    end

    Sessions = [Sessions; srow]; %#ok<AGROW>
end

if height(Sessions) == 0
    error('No subject/session pairs had both restEC and restEO.');
end

Sessions = sortrows(Sessions, {'group_code','subject_id','session'});
Sessions.session_index = (1:height(Sessions))';

selectedKeys = strcat(Sessions.subject_id, "__", Sessions.session);
rowKeys = strcat(Tbase.subject_id, "__", Tbase.session);
lockedRows = Tbase(ismember(rowKeys, selectedKeys), :);

lockedRows = sortrows(lockedRows, {'subject_id','session','task'});
lockedRows = keepFirstPerSubjectSessionTask(lockedRows);

%% Inject downstream-compatible fields
lockedRows.local_derivative_dir = strings(height(lockedRows),1);

lockedRows.bdf_path_original      = strings(height(lockedRows),1);
lockedRows.json_path_original     = strings(height(lockedRows),1);
lockedRows.channels_path_original = strings(height(lockedRows),1);

lockedRows.group = strings(height(lockedRows),1);
lockedRows.group_code = NaN(height(lockedRows),1);
lockedRows.match_pair = NaN(height(lockedRows),1);        % compatibility only
lockedRows.session_index = NaN(height(lockedRows),1);
lockedRows.condition = lockedRows.task;
lockedRows.condition_code = double(lockedRows.task == "restEO");

for i = 1:height(lockedRows)
    sid = lockedRows.subject_id(i);
    ses = lockedRows.session(i);
    idx = find(Sessions.subject_id == sid & Sessions.session == ses, 1);

    lockedRows.group(i) = Sessions.group(idx);
    lockedRows.group_code(i) = Sessions.group_code(idx);
    lockedRows.session_index(i) = Sessions.session_index(idx);
    lockedRows.match_pair(i) = Sessions.session_index(idx);
end

lockedRows = sortrows(lockedRows, {'session_index','group_code','condition_code'});

%% Copy V3.1 BDF files into B derivative folder
% Structure:
%   locked_input_files\HC\restEC\sub-xxx\ses-y\files
%   locked_input_files\MDD\restEO\sub-xxx\ses-y\files
fprintf('\nCopying selected V3.1 input files into B derivative folder...\n');

nCopied = 0;
nMissingDuringCopy = 0;

for i = 1:height(lockedRows)

    subjectID = lockedRows.subject_id(i);
    sessionID = lockedRows.session(i);
    groupName = lockedRows.group(i);
    condition = lockedRows.condition(i);

    dstDir = fullfile(lockedDataDir, groupName, condition, subjectID, sessionID);
    if ~exist(dstDir, 'dir'), mkdir(dstDir); end

    srcBdf      = lockedRows.bdf_path(i);
    srcJson     = lockedRows.json_path(i);
    srcChannels = lockedRows.channels_path(i);

    srcFiles = {srcBdf; srcJson; srcChannels};
    localFiles = strings(numel(srcFiles),1);

    for f = 1:numel(srcFiles)
        src = char(srcFiles{f});

        if isfile(src)
            [~, name, ext] = fileparts(src);
            dst = fullfile(dstDir, [name ext]);
            copyfile(src, dst);
            localFiles(f) = string(dst);
            nCopied = nCopied + 1;
        else
            localFiles(f) = missing;
            nMissingDuringCopy = nMissingDuringCopy + 1;
            warning('Missing source file during copy: %s', src);
        end
    end

    lockedRows.local_derivative_dir(i) = string(dstDir);

    lockedRows.bdf_path_original(i)      = srcBdf;
    lockedRows.json_path_original(i)     = srcJson;
    lockedRows.channels_path_original(i) = srcChannels;

    lockedRows.bdf_path(i)      = localFiles(1);
    lockedRows.json_path(i)     = localFiles(2);
    lockedRows.channels_path(i) = localFiles(3);
end

fprintf('Copied files: %d\n', nCopied);
fprintf('Missing during copy: %d\n', nMissingDuringCopy);

%% Save outputs
subjectCSV = fullfile(outDir, 'TDBRAIN_subject_shortlist_FORMAL_STATUS_ALL_SESSIONS_subjects.csv');
rowCSV     = fullfile(outDir, 'TDBRAIN_subject_shortlist_FORMAL_STATUS_ALL_SESSIONS_rows_EC_EO.csv');

% Downstream-compatible aliases. Existing later scripts can keep using the
% LOCKED filenames, but C_import must read bdf_path for V3.1.
subjectCSV_compat = fullfile(outDir, 'TDBRAIN_subject_shortlist_LOCKED_subjects.csv');
rowCSV_compat     = fullfile(outDir, 'TDBRAIN_subject_shortlist_LOCKED_rows_EC_EO.csv');

writetable(Sessions, subjectCSV);
writetable(lockedRows, rowCSV);
writetable(Sessions, subjectCSV_compat);
writetable(lockedRows, rowCSV_compat);

summaryCSV = fullfile(outDir, 'TDBRAIN_subject_shortlist_FORMAL_STATUS_ALL_SESSIONS_summary.csv');
Summary = makeSummaryTable(Sessions, lockedRows);
writetable(Summary, summaryCSV);

fprintf('\nFormal-status all-session cohort:\n');
fprintf('HC subject-sessions:  %d\n', sum(Sessions.group == "HC"));
fprintf('MDD subject-sessions: %d\n', sum(Sessions.group == "MDD"));
fprintf('Total subject-sessions: %d\n', height(Sessions));

fprintf('\nUnique subjects:\n');
fprintf('HC unique subjects:  %d\n', numel(unique(Sessions.subject_id(Sessions.group == "HC"))));
fprintf('MDD unique subjects: %d\n', numel(unique(Sessions.subject_id(Sessions.group == "MDD"))));
fprintf('Total unique subjects: %d\n', numel(unique(Sessions.subject_id)));

fprintf('\nSelected row cohort:\n');
fprintf('Rows total: %d\n', height(lockedRows));
fprintf('restEC rows: %d\n', sum(lockedRows.condition == "restEC"));
fprintf('restEO rows: %d\n', sum(lockedRows.condition == "restEO"));

fprintf('\nSaved:\n');
fprintf('  %s\n', subjectCSV);
fprintf('  %s\n', rowCSV);
fprintf('  %s\n', subjectCSV_compat);
fprintf('  %s\n', rowCSV_compat);
fprintf('  %s\n', summaryCSV);
fprintf('  copied files under: %s\n', lockedDataDir);

fprintf('\n====================================================\n');
fprintf('B_subject_shortlist_FORMAL_STATUS_ALL_SESSIONS_V31 finished\n');
fprintf('====================================================\n');

diary off;

%% =========================================================================
% Helpers
%% =========================================================================
function col = getOptionalColumn(T, names)
    col = NaN(height(T),1);
    for i = 1:numel(names)
        if any(strcmp(T.Properties.VariableNames, names{i}))
            col = T.(names{i});
            return;
        end
    end
end

function x = parseNumericColumn(col)
    if isnumeric(col)
        x = double(col);
        return;
    end

    s = string(col);
    s = strip(s);
    s = replace(s, ",", ".");
    x = str2double(s);

    tooLarge = x > 120 & x < 12000;
    x(tooLarge) = x(tooLarge) ./ 100;
end

function val = parseOneNumeric(row, names)
    val = NaN;
    for i = 1:numel(names)
        if any(strcmp(row.Properties.VariableNames, names{i}))
            v = row.(names{i});
            if istable(v), v = v{1,1}; end %#ok<ISTBLE>
            vv = parseNumericColumn(v);
            if ~isempty(vv), val = vv(1); end
            return;
        end
    end
end

function Tout = keepFirstPerSubjectSessionTask(Tin)
    keys = strcat(string(Tin.subject_id), "__", string(Tin.session), "__", string(Tin.task));
    [~, ia] = unique(keys, 'stable');
    Tout = Tin(sort(ia), :);
end

function Summary = makeSummaryTable(Sessions, Rows)
    names = strings(0,1);
    values = strings(0,1);

    names(end+1) = "HC_subject_sessions";
    values(end+1) = string(sum(Sessions.group == "HC"));

    names(end+1) = "MDD_subject_sessions";
    values(end+1) = string(sum(Sessions.group == "MDD"));

    names(end+1) = "Total_subject_sessions";
    values(end+1) = string(height(Sessions));

    names(end+1) = "HC_unique_subjects";
    values(end+1) = string(numel(unique(Sessions.subject_id(Sessions.group == "HC"))));

    names(end+1) = "MDD_unique_subjects";
    values(end+1) = string(numel(unique(Sessions.subject_id(Sessions.group == "MDD"))));

    names(end+1) = "Total_unique_subjects";
    values(end+1) = string(numel(unique(Sessions.subject_id)));

    names(end+1) = "Rows_total";
    values(end+1) = string(height(Rows));

    names(end+1) = "Rows_restEC";
    values(end+1) = string(sum(Rows.condition == "restEC"));

    names(end+1) = "Rows_restEO";
    values(end+1) = string(sum(Rows.condition == "restEO"));

    Summary = table(names, values, 'VariableNames', {'metric','value'});
end
