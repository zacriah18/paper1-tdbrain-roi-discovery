%% =========================================================================
% A_inventory_V31.m
% Clean inventory builder for TDBRAIN V3.1 BDF resting-state EEG
%
% Purpose:
%   1) Inventory all restEC/restEO .bdf files in the new V3.1 structure
%   2) Attach participant metadata from TDBRAIN_participants_V3.xlsx
%   3) Save a full inventory + subject/task counts for later shortlisting
%
% Expected V3.1 layout:
%   C:\MATLAB\2026 TDBRAIN dataset\dataset\
%       TDBRAIN_participants_V3.xlsx
%       TDBRAIN_Dataset_V3\
%           sub-XXXXXXXX\
%               ses-N\
%                   eeg\
%                       sub-XXXXXXXX_ses-N_task-restEC_eeg.bdf
%                       sub-XXXXXXXX_ses-N_task-restEC_eeg.json
%                       sub-XXXXXXXX_ses-N_task-restEC_channels.tsv
%                       sub-XXXXXXXX_ses-N_task-restEO_eeg.bdf
%                       ...
%
% Notes:
%   - This script ignores oddball/ERP files for now.
%   - Resting files are plain BDF; no events.tsv is expected/required.
%   - The BioSemi Status channel is normal in V3.1 and is not filtered here.
% =========================================================================

clear; clc;

%% Paths
rootDir = 'C:\MATLAB\2026 TDBRAIN dataset';

datasetDir = fullfile(rootDir, 'dataset', 'TDBRAIN_Dataset_V3');
participantsFile = fullfile(rootDir, 'dataset', 'TDBRAIN_participants_V3.xlsx');
derivDir = fullfile(rootDir, 'derivatives');

outDir = fullfile(derivDir, 'A_inventory_V31');
if ~exist(outDir, 'dir'), mkdir(outDir); end

logFile = fullfile(outDir, 'A_inventory_V31_log.txt');
if exist(logFile, 'file'), delete(logFile); end
diary(logFile);

fprintf('\n====================================================\n');
fprintf('A_inventory_V31 started\n');
fprintf('Root:         %s\n', rootDir);
fprintf('Dataset:      %s\n', datasetDir);
fprintf('Participants: %s\n', participantsFile);
fprintf('Output:       %s\n', outDir);
fprintf('====================================================\n\n');

if ~isfolder(datasetDir)
    error('Dataset directory not found: %s', datasetDir);
end

if ~isfile(participantsFile)
    error('Participants file not found: %s', participantsFile);
end

%% Load metadata

P = readtable(participantsFile,'VariableNamingRule','preserve');

fprintf('Loaded metadata: %d rows, %d columns\n',height(P),width(P));

%% ----- V3.1 fixed metadata schema -----

pidName        = "TDBRAIN_ID";
sessName       = "sessID";
ageName        = "age";
genderName     = "gender";
indicationName = "indication";
formalName     = "formal_status";
splitName      = "DISC/REP";

required = [pidName sessName ageName indicationName formalName splitName];

for i = 1:numel(required)
    if ~ismember(required(i), string(P.Properties.VariableNames))
        error("Missing required column: %s", required(i));
    end
end

fprintf("Participant ID : %s\n", pidName);
fprintf("Session column : %s\n", sessName);
fprintf("Diagnosis      : %s\n", indicationName);
fprintf("Formal status  : %s\n", formalName);
fprintf("Dataset split  : %s\n", splitName);

P.participant_key = normalizeParticipantID(P.(pidName));
P.session_key     = normalizeSessionID(P.(sessName));

fprintf('Using participant ID column: %s\n', pidName);

if isempty(sessName)
    fprintf('No session column found in metadata. Matching metadata by subject only.\n');
else
    fprintf('Using session ID column: %s\n', sessName);
end

% Add normalized metadata keys for robust joining.
P.participant_key = normalizeParticipantID(P.(pidName));

if isempty(sessName)
    P.session_key = NaN(height(P), 1);
else
    P.session_key = normalizeSessionID(P.(sessName));
end

% Remove duplicate metadata rows by participant/session key while keeping the
% first occurrence. This avoids join expansion if metadata has duplicates.
if isempty(sessName)
    [~, keepIdx] = unique(P.participant_key, 'stable');
else
    comboKey = P.participant_key + "_ses-" + string(P.session_key);
    [~, keepIdx] = unique(comboKey, 'stable');
end

if numel(keepIdx) < height(P)
    fprintf('Metadata duplicate rows detected: %d duplicates removed for joining\n', height(P) - numel(keepIdx));
end

Pjoin = P(keepIdx, :);

%% Find V3.1 resting-state BDF files: EC + EO only
patterns = {
    '*task-restEC_eeg.bdf'
    '*task-restEO_eeg.bdf'
};

bdfFiles = [];

for p = 1:numel(patterns)
    found = dir(fullfile(datasetDir, 'sub-*', 'ses-*', 'eeg', patterns{p}));
    bdfFiles = [bdfFiles; found]; %#ok<AGROW>
end

fprintf('Found %d resting-state .bdf files including EC + EO\n', numel(bdfFiles));

if isempty(bdfFiles)
    error('No resting .bdf files found. Check datasetDir and file structure.');
end

%% Build file inventory
n = numel(bdfFiles);

subject_id    = strings(n,1);
subject_num   = strings(n,1);
session       = strings(n,1);
sessID        = NaN(n,1);
task          = strings(n,1);
condition     = strings(n,1);

bdf_path      = strings(n,1);
json_path     = strings(n,1);
channels_path = strings(n,1);

has_bdf       = false(n,1);
has_json      = false(n,1);
has_channels  = false(n,1);

bdf_MB        = NaN(n,1);
json_KB       = NaN(n,1);
channels_KB   = NaN(n,1);

for i = 1:n

    bdfPath = fullfile(bdfFiles(i).folder, bdfFiles(i).name);

    tokens = regexp(bdfFiles(i).name, ...
        '^sub-(\d+)_ses-(\d+)_task-(restEC|restEO)_eeg\.bdf$', ...
        'tokens', 'once');

    if isempty(tokens)
        warning('Could not parse filename: %s', bdfFiles(i).name);
        continue;
    end

    subjectNum = string(tokens{1});
    sessionNum = str2double(tokens{2});
    taskName   = string(tokens{3});

    subjectID = "sub-" + subjectNum;
    sessionID = "ses-" + string(sessionNum);

    jsonPath     = replace(bdfPath, '_eeg.bdf', '_eeg.json');
    channelsPath = replace(bdfPath, '_eeg.bdf', '_channels.tsv');

    subject_id(i)    = subjectID;
    subject_num(i)   = subjectNum;
    session(i)       = sessionID;
    sessID(i)        = sessionNum;
    task(i)          = taskName;
    condition(i)     = replace(taskName, "rest", "eyes_");

    bdf_path(i)      = string(bdfPath);
    json_path(i)     = string(jsonPath);
    channels_path(i) = string(channelsPath);

    has_bdf(i)       = isfile(bdfPath);
    has_json(i)      = isfile(jsonPath);
    has_channels(i)  = isfile(channelsPath);

    bdf_MB(i)        = fileSizeMB(bdfPath);
    json_KB(i)       = fileSizeKB(jsonPath);
    channels_KB(i)   = fileSizeKB(channelsPath);
end

rows = table(subject_id, subject_num, session, sessID, task, condition, ...
    bdf_path, json_path, channels_path, ...
    has_bdf, has_json, has_channels, ...
    bdf_MB, json_KB, channels_KB);

% Remove any unparsed rows, just in case.
rows = rows(subject_id ~= "", :);

rows.participant_key = normalizeParticipantID(rows.subject_num);
rows.session_key = rows.sessID;

%% Join file inventory to metadata
if isempty(sessName)
    rows = outerjoin(rows, Pjoin, ...
        'Keys', 'participant_key', ...
        'MergeKeys', true, ...
        'Type', 'left');
else
    rows = outerjoin(rows, Pjoin, ...
        'Keys', {'participant_key', 'session_key'}, ...
        'MergeKeys', true, ...
        'Type', 'left');
end

% outerjoin can reorder; sort back into subject/session/task order.
rows = sortrows(rows, {'subject_id', 'session_key', 'task'});
rows.has_metadata = ~ismissing(rows.(pidName));

%% Cohort and usability flags
rows.is_ses1 = rows.session_key == 1;

ageName = findFirstColumn(rows, {'age', 'Age', 'AGE'});
if isempty(ageName)
    rows.age_num = NaN(height(rows), 1);
    rows.is_adult = true(height(rows), 1);  % do not exclude if age missing at inventory stage
    fprintf('No age column found after metadata join. is_adult set TRUE for inventory only.\n');
else
    rows.age_num = str2double(string(rows.(ageName)));
    rows.is_adult = rows.age_num >= 18;
end

indicationName = findFirstColumn(rows, {'indication', 'Indication'});
formalName = findFirstColumn(rows, { ...
    'formal_status', 'formal Dx', 'formalDx', 'formal diagnosis', ...
    'diagnosis', 'Diagnosis', 'diagnostic_status', 'status'});
datasetName = findFirstColumn(rows, {'Dataset', 'dataset', 'DISC/REP', 'DISC_REP', 'split', 'DatasetSplit'});

indicationText = getStringColumn(rows, indicationName);
formalText     = getStringColumn(rows, formalName);
datasetText    = getStringColumn(rows, datasetName);

rows.is_MDD = contains(indicationText, "mdd") | ...
              contains(indicationText, "depress") | ...
              contains(formalText, "mdd") | ...
              contains(formalText, "depress") | ...
              contains(datasetText, "mdd");

rows.is_HC = contains(indicationText, "healthy") | ...
             contains(indicationText, "control") | ...
             contains(indicationText, "hc") | ...
             contains(formalText, "healthy") | ...
             contains(formalText, "control") | ...
             contains(formalText, "hc") | ...
             contains(datasetText, "healthy") | ...
             contains(datasetText, "control") | ...
             contains(datasetText, "hc");

splitName = findFirstColumn(rows, {'DISC/REP', 'DISC_REP', 'DatasetSplit', 'split', 'dataset_split'});
splitText = getStringColumn(rows, splitName);

rows.is_discovery   = contains(splitText, "disc");
rows.is_replication = contains(splitText, "rep");
rows.is_diagnostic_replication = contains(splitText, "diagnostic") | contains(splitText, "diag");
rows.is_prognostic_replication = contains(splitText, "prognostic") | contains(splitText, "prog");

rows.has_all_files = rows.has_bdf & rows.has_json & rows.has_channels;

% For resting V3.1 files, .events.tsv is not required.
rows.usable_resting = rows.has_all_files;
rows.usable_resting_ses1 = rows.usable_resting & rows.is_ses1;

% Convenience flag for the planned shortlist stage.
rows.is_target_group = rows.is_HC | rows.is_MDD;
rows.candidate_HC_MDD_ses1_rest = rows.usable_resting_ses1 & rows.is_adult & rows.is_target_group;

%% Save full inventory
outCSV = fullfile(outDir, 'TDBRAIN_V31_rest_inventory_EC_EO.csv');
writetable(rows, outCSV);

fprintf('\nSaved full inventory:\n%s\n', outCSV);
fprintf('Total matched resting rows EC+EO: %d\n', height(rows));
fprintf('restEC rows: %d\n', sum(rows.task == "restEC"));
fprintf('restEO rows: %d\n', sum(rows.task == "restEO"));
fprintf('Rows with metadata: %d\n', sum(rows.has_metadata));
fprintf('Rows missing metadata: %d\n', sum(~rows.has_metadata));
fprintf('Usable EC+EO all sessions: %d\n', sum(rows.usable_resting));
fprintf('Usable EC+EO ses-1: %d\n', sum(rows.usable_resting_ses1));
fprintf('Candidate HC/MDD adult usable ses-1 rows: %d\n', sum(rows.candidate_HC_MDD_ses1_rest));
fprintf('MDD adult usable ses-1 rows: %d\n', sum(rows.usable_resting_ses1 & rows.is_adult & rows.is_MDD));
fprintf('HC adult usable ses-1 rows: %d\n', sum(rows.usable_resting_ses1 & rows.is_adult & rows.is_HC));

%% Save subject-task counts
usableRows = rows(rows.usable_resting_ses1, :);

[G, subject_id_g, task_g] = findgroups(usableRows.subject_id, usableRows.task);
n_files = splitapply(@numel, usableRows.bdf_path, G);

subjectTaskCounts = table(subject_id_g, task_g, n_files, ...
    'VariableNames', {'subject_id', 'task', 'n_files'});

summaryCSV = fullfile(outDir, 'TDBRAIN_V31_rest_inventory_subject_task_counts.csv');
writetable(subjectTaskCounts, summaryCSV);

fprintf('Saved subject-task counts:\n%s\n', summaryCSV);

%% Save subject-level EC/EO completeness table for shortlist stage
[G2, subject_id2, sessID2] = findgroups(rows.subject_id, rows.session_key);

has_restEC = splitapply(@(x) any(x == "restEC"), rows.task, G2);
has_restEO = splitapply(@(x) any(x == "restEO"), rows.task, G2);

is_HC_sub = splitapply(@(x) any(x), rows.is_HC, G2);
is_MDD_sub = splitapply(@(x) any(x), rows.is_MDD, G2);
is_adult_sub = splitapply(@(x) any(x), rows.is_adult, G2);
has_metadata_sub = splitapply(@(x) any(x), rows.has_metadata, G2);
is_ses1_sub = sessID2 == 1;

subjectCompleteness = table(subject_id2, sessID2, is_ses1_sub, ...
    has_restEC, has_restEO, has_metadata_sub, is_adult_sub, is_HC_sub, is_MDD_sub);

subjectCompleteness.has_EC_EO_pair = subjectCompleteness.has_restEC & subjectCompleteness.has_restEO;
subjectCompleteness.candidate_HC_MDD_EC_EO_ses1 = ...
    subjectCompleteness.is_ses1_sub & ...
    subjectCompleteness.has_EC_EO_pair & ...
    subjectCompleteness.has_metadata_sub & ...
    subjectCompleteness.is_adult_sub & ...
    (subjectCompleteness.is_HC_sub | subjectCompleteness.is_MDD_sub);

completeCSV = fullfile(outDir, 'TDBRAIN_V31_rest_subject_EC_EO_completeness.csv');
writetable(subjectCompleteness, completeCSV);

fprintf('Saved subject EC/EO completeness table:\n%s\n', completeCSV);

fprintf('\nSubject-level candidate counts, ses-1 EC+EO:\n');
fprintf('HC subjects:  %d\n', sum(subjectCompleteness.candidate_HC_MDD_EC_EO_ses1 & subjectCompleteness.is_HC_sub));
fprintf('MDD subjects: %d\n', sum(subjectCompleteness.candidate_HC_MDD_EC_EO_ses1 & subjectCompleteness.is_MDD_sub));
fprintf('Total:        %d\n', sum(subjectCompleteness.candidate_HC_MDD_EC_EO_ses1));

fprintf('\n====================================================\n');
fprintf('A_inventory_V31 finished\n');
fprintf('====================================================\n');

diary off
if exist(logFile, 'file')
    try
        delete(logFile);
    catch
        warning('Could not delete old log file. Continuing and appending/overwriting diary.');
    end
end
diary(logFile);

%% Helpers
function colName = findFirstColumn(T, possibleNames)
    colName = '';
    if isempty(possibleNames)
        return;
    end

    vars = T.Properties.VariableNames;

    % Exact match first
    for i = 1:numel(possibleNames)
        idx = strcmp(vars, possibleNames{i});
        if any(idx)
            colName = vars{find(idx, 1, 'first')};
            return;
        end
    end

    % Case/space/punctuation insensitive fallback
    normVars = normalizeColumnNames(vars);
    normPoss = normalizeColumnNames(possibleNames);

    for i = 1:numel(normPoss)
        idx = strcmp(normVars, normPoss{i});
        if any(idx)
            colName = vars{find(idx, 1, 'first')};
            return;
        end
    end
end

function out = normalizeColumnNames(names)
    out = strings(size(names));
    for i = 1:numel(names)
        s = lower(string(names{i}));
        s = regexprep(s, '[^a-z0-9]', '');
        out(i) = s;
    end
end

function key = normalizeParticipantID(x)
    key = string(x);
    key = strip(key);
    key = erase(key, "sub-");
    key = erase(key, "SUB-");
    key = regexprep(key, '\.0$', '');   % Excel numeric IDs sometimes become 123.0
end

function sess = normalizeSessionID(x)
    sx = string(x);
    sx = strip(sx);
    sx = erase(sx, "ses-");
    sx = erase(sx, "SES-");
    sess = str2double(sx);
end

function s = getStringColumn(T, colName)
    if isempty(colName)
        s = strings(height(T), 1);
        return;
    end

    if any(strcmp(T.Properties.VariableNames, colName))
        s = lower(string(T.(colName)));
    else
        s = strings(height(T), 1);
    end
end

function mb = fileSizeMB(pathStr)
    if isfile(pathStr)
        d = dir(pathStr);
        mb = d.bytes / 1024 / 1024;
    else
        mb = NaN;
    end
end

function kb = fileSizeKB(pathStr)
    if isfile(pathStr)
        d = dir(pathStr);
        kb = d.bytes / 1024;
    else
        kb = NaN;
    end
end
