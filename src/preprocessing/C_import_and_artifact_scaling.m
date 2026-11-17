%% =========================================================================
% C_import_and_artifact_scaling_V31.m
%
% V3.1 C-stage replacement for TDBRAIN EEG DCM pipeline.
%
% Purpose:
%   1) Import TDBRAIN V3.1 BDF resting-state EEG into SPM M/EEG.
%   2) Apply deterministic preprocessing only:
%        - attach EEG sensor locations
%        - assign channel types
%        - high-pass filter
%        - average reference montage
%        - low-pass filter
%        - downsample to target sampling rate
%        - epoch continuous rest into fixed windows
%   3) DO NOT reject data here.
%   4) Export amplitude/statistical summaries to choose D-stage artefact thresholds.
%
% Output names are intentionally unchanged from the previous C-stage:
%   derivatives/C_import_and_artifact_scaling/
%       C_import_and_artifact_scaling_summary.tsv
%       C_stagewise_amplitude_stats.csv
%       C_threshold_candidate_stats.csv
%       C_threshold_rejection_grid.csv
%
% Input:
%   derivatives/B_subject_shortlist_FORMAL_STATUS_ALL_SESSIONS/
%       TDBRAIN_subject_shortlist_LOCKED_rows_EC_EO.csv
%
% Expected V3.1 row columns:
%   bdf_path, json_path, channels_path, subject_id, group, condition
%
% Notes:
%   - V3.1 resting files are BDF, not BrainVision .vhdr/.eeg/.vmrk.
%   - The BioSemi Status channel is expected in BDF files and is dropped
%     before SPM conversion for the resting-state pipeline.
%   - No BrainVision manual parser is used in this version.
% =========================================================================

clear; clc;

%% -------------------------------------------------------------------------
% Clean path + SPM
% -------------------------------------------------------------------------

restoredefaultpath;

rootDir = 'C:\MATLAB\2026 TDBRAIN dataset';
spmDir  = 'C:\MATLAB\spm';

addpath(spmDir);
addpath(genpath(fullfile(spmDir, 'config')));
addpath(genpath(fullfile(spmDir, 'matlabbatch')));

spm('defaults','eeg');
spm_jobman('initcfg');

%% -------------------------------------------------------------------------
% Config
% -------------------------------------------------------------------------

cfg = struct();

% V3.1 BDF is lossless 24-bit. FieldTrip/SPM normally returns EEG in the
% physical units defined by the BDF header. We retain the historical label
% and output naming convention from the V2 C-stage.
cfg.scaleMultiplierToUV = 1;

% Deterministic preprocessing. No rejection in C.
cfg.highpass = 1;
cfg.lowpass  = 48;

% Downsample after low-pass filtering and before epoching.
% For DCM Fdcm up to 48 Hz, 125 Hz gives Nyquist = 62.5 Hz.
cfg.targetFs = 125;

cfg.epoch_ms = 4000;
cfg.filterOrder = 5;

% Runtime controls.
cfg.overwriteExisting = true;
cfg.previewFirstN = 4;

% Candidate thresholds to evaluate, NOT apply.
cfg.candidate_peak2peak_uV = [100 150 200 250 300 400 500 750 1000 1500 2000];
cfg.candidate_maxabs_uV    = [100 150 200 250 300 400 500 750 1000 1500 2000];
cfg.candidate_jump_uV      = [20 40 75 100 150 200 300 500 750 1000];

sensorFile = fullfile(rootDir, 'ZZ_standard_1005.elc');

eegChanFile   = fullfile(rootDir, 'ZZ_channel_selection.mat');
eogChanFile   = fullfile(rootDir, 'ZZ_eog_channel_selection.mat');
otherChanFile = fullfile(rootDir, 'ZZ_other_channel_selection.mat');

shortlistCSV = fullfile(rootDir, ...
    'derivatives', ...
    'B_subject_shortlist_FORMAL_STATUS_ALL_SESSIONS', ...
    'TDBRAIN_subject_shortlist_LOCKED_rows_EC_EO.csv');

outRoot = fullfile(rootDir, ...
    'derivatives', ...
    'C_import_and_artifact_scaling');

if ~exist(outRoot, 'dir'), mkdir(outRoot); end

logFile = fullfile(outRoot, 'C_import_and_artifact_scaling_log.txt');
diary off;
if exist(logFile, 'file')
    try
        delete(logFile);
    catch
        warning('Could not delete old C log file. Continuing with diary target: %s', logFile);
    end
end
diary(logFile);

fprintf('\n============================================================\n');
fprintf('C IMPORT + ARTIFACT SCALING PREP - V3.1 BDF\n');
fprintf('Output root: %s\n', outRoot);
fprintf('Scale      : imported BDF data * %.10g -> labelled uV\n', cfg.scaleMultiplierToUV);
fprintf('High-pass  : %.3g Hz\n', cfg.highpass);
fprintf('Low-pass   : %.3g Hz\n', cfg.lowpass);
fprintf('Downsample : %.3g Hz\n', cfg.targetFs);
fprintf('Epoch      : %.3g ms\n', cfg.epoch_ms);
fprintf('============================================================\n\n');

if ~isfile(shortlistCSV)
    error('Shortlist CSV not found: %s', shortlistCSV);
end

T = readtable(shortlistCSV, 'VariableNamingRule', 'preserve');

required = {'subject_id','group','condition','bdf_path','json_path','channels_path'};
for r = 1:numel(required)
    if ~any(strcmp(T.Properties.VariableNames, required{r}))
        error('Required V3.1 shortlist column missing: %s', required{r});
    end
end

T.subject_id    = string(T.subject_id);
T.group         = string(T.group);
T.condition     = string(T.condition);
T.bdf_path      = string(T.bdf_path);
T.json_path     = string(T.json_path);
T.channels_path = string(T.channels_path);

summaryRows   = table();
stageRows     = table();
candidateRows = table();
gridRows      = table();

%% -------------------------------------------------------------------------
% Main loop
% -------------------------------------------------------------------------

for i = 1:height(T)

    subjectID = char(T.subject_id(i));
    groupName = char(T.group(i));
    condition = char(T.condition(i));

    bdfFile      = char(T.bdf_path(i));
    jsonFile     = char(T.json_path(i));
    channelsFile = char(T.channels_path(i));

    rowBase = sprintf('%s_%s_%s_scale1_as_uV', subjectID, groupName, condition);

    subjOutDir = fullfile(outRoot, groupName, condition, subjectID);
    if ~exist(subjOutDir, 'dir'), mkdir(subjOutDir); end

    fprintf('\n============================================================\n');
    fprintf('%03d/%03d | %s | %s | %s\n', i, height(T), subjectID, groupName, condition);
    fprintf('BDF      : %s\n', bdfFile);
    fprintf('JSON     : %s\n', jsonFile);
    fprintf('CHANNELS : %s\n', channelsFile);
    fprintf('OUT      : %s\n', subjOutDir);
    fprintf('============================================================\n');

    try
        if ~isfile(bdfFile),      error('Missing BDF file: %s', bdfFile); end
        if ~isfile(jsonFile),     error('Missing JSON sidecar: %s', jsonFile); end
        if ~isfile(channelsFile), error('Missing channels TSV: %s', channelsFile); end

        %% Step C00: import BDF to SPM via FieldTrip structure
        ftdata = readTDBRAINBDFAsFieldTrip(bdfFile, cfg.scaleMultiplierToUV);

        importBase = fullfile(subjOutDir, rowBase);
        importMat  = [importBase '.mat'];

        if cfg.overwriteExisting || ~isfile(importMat)
            deleteIfExists([importBase '.mat']);
            deleteIfExists([importBase '.dat']);
            fprintf('Converting V3.1 BDF FieldTrip struct to SPM M/EEG...\n');
            D = spm_eeg_ft2spm(ftdata, importBase);
            D = units(D, ':', 'uV');
            D = conditions(D, 1, 'rest');
            save(D);
        else
            D = spm_eeg_load(importMat);
        end

        Dfile = importMat;
        stageRows = addStageRow(stageRows, subjectID, groupName, condition, ...
            'C00_import_scale1', Dfile);

        if i <= cfg.previewFirstN
            try
                Dprev = spm_eeg_load(Dfile);
                eegIdxPrev = getEEGChannelIdx(Dprev);
                fig = figure('Visible','off');
                plot(double(Dprev(eegIdxPrev(1),: ,1)));
                title(sprintf('%s %s imported BDF preview', subjectID, condition), 'Interpreter','none');
                ylabel('uV-labelled'); xlabel('Samples');
                saveas(fig, fullfile(subjOutDir, sprintf('%s_C00_import_preview.png', rowBase)));
                close(fig);
            catch MEprev
                warning('Preview failed: %s', MEprev.message);
            end
        end

        %% Step C01: attach EEG sensor locations only
        clear matlabbatch;
        matlabbatch{1}.spm.meeg.preproc.prepare.D = {Dfile};
        if isfile(sensorFile)
            matlabbatch{1}.spm.meeg.preproc.prepare.task{1}.loadeegsens.eegsens = {sensorFile};
            matlabbatch{1}.spm.meeg.preproc.prepare.task{1}.loadeegsens.megmatch.nomatch = 1;
        else
            warning('Missing sensor file: %s', sensorFile);
        end
        spm_jobman('run', matlabbatch);
        stageRows = addStageRow(stageRows, subjectID, groupName, condition, ...
            'C01_prepare_sensors', Dfile);

        %% Step C01b: assign channel types using SPM Prepare/settype
        Dfile = runSPMChannelTypePrepare(Dfile, eegChanFile, eogChanFile, otherChanFile);
        verifyTDBRAINChannelTypes(Dfile, true);

        stageRows = addStageRow(stageRows, subjectID, groupName, condition, ...
            'C01b_set_channel_types', Dfile);

        %% Step C02: high-pass filter
        clear matlabbatch;
        matlabbatch{1}.spm.meeg.preproc.filter.D = {Dfile};
        matlabbatch{1}.spm.meeg.preproc.filter.type = 'butterworth';
        matlabbatch{1}.spm.meeg.preproc.filter.band = 'high';
        matlabbatch{1}.spm.meeg.preproc.filter.freq = cfg.highpass;
        matlabbatch{1}.spm.meeg.preproc.filter.dir = 'twopass';
        matlabbatch{1}.spm.meeg.preproc.filter.order = cfg.filterOrder;
        matlabbatch{1}.spm.meeg.preproc.filter.prefix = 'f';
        spm_jobman('run', matlabbatch);
        Dfile = prefixedMat(Dfile, 'f');
        stageRows = addStageRow(stageRows, subjectID, groupName, condition, ...
            'C02_highpass', Dfile);

        verifyTDBRAINChannelTypes(Dfile, true);

        %% Step C03: create and apply average-reference montage
        avrefFile = fullfile(subjOutDir, 'avref_montage.mat');
        deleteIfExists(avrefFile);

        clear matlabbatch;
        matlabbatch{1}.spm.meeg.preproc.prepare.D = {Dfile};
        matlabbatch{1}.spm.meeg.preproc.prepare.task{1}.avref.fname = avrefFile;
        spm_jobman('run', matlabbatch);
        stageRows = addStageRow(stageRows, subjectID, groupName, condition, ...
            'C03a_prepare_avref_definition', Dfile);

        clear matlabbatch;
        matlabbatch{1}.spm.meeg.preproc.montage.D = {Dfile};
        matlabbatch{1}.spm.meeg.preproc.montage.mode.write.montspec.montage.montagefile = {avrefFile};
        matlabbatch{1}.spm.meeg.preproc.montage.mode.write.montspec.montage.keepothers = 0;
        matlabbatch{1}.spm.meeg.preproc.montage.mode.write.blocksize = 655360;
        matlabbatch{1}.spm.meeg.preproc.montage.mode.write.prefix = 'M';
        spm_jobman('run', matlabbatch);
        Dfile = prefixedMat(Dfile, 'M');

        stageRows = addStageRow(stageRows, subjectID, groupName, condition, ...
            'C03b_apply_avref', Dfile);

        verifyTDBRAINChannelTypes(Dfile, false);

        %% Step C04: low-pass filter
        clear matlabbatch;
        matlabbatch{1}.spm.meeg.preproc.filter.D = {Dfile};
        matlabbatch{1}.spm.meeg.preproc.filter.type = 'butterworth';
        matlabbatch{1}.spm.meeg.preproc.filter.band = 'low';
        matlabbatch{1}.spm.meeg.preproc.filter.freq = cfg.lowpass;
        matlabbatch{1}.spm.meeg.preproc.filter.dir = 'twopass';
        matlabbatch{1}.spm.meeg.preproc.filter.order = cfg.filterOrder;
        matlabbatch{1}.spm.meeg.preproc.filter.prefix = 'f';
        spm_jobman('run', matlabbatch);
        Dfile = prefixedMat(Dfile, 'f');
        stageRows = addStageRow(stageRows, subjectID, groupName, condition, ...
            'C04_lowpass', Dfile);

        verifyTDBRAINChannelTypes(Dfile, false);

        %% Step C04b: downsample after low-pass, before epoching
        Dfile = runSPMDownsample(Dfile, cfg.targetFs);
        stageRows = addStageRow(stageRows, subjectID, groupName, condition, ...
            sprintf('C04b_downsample_%gHz', cfg.targetFs), Dfile);

        verifyTDBRAINChannelTypes(Dfile, false);

        %% Step C05: epoch continuous rest into fixed windows
        Dfile = runEpochWithFallback(Dfile, cfg.epoch_ms, 'rest');
        stageRows = addStageRow(stageRows, subjectID, groupName, condition, ...
            'C05_epoch_4s', Dfile);

        verifyTDBRAINChannelTypes(Dfile, false);

        Dfinal = spm_eeg_load(Dfile);

        finalStats = quickStatsSafe(Dfinal);
        cand = thresholdCandidateStats(Dfinal);

        candidateRow = table();
        candidateRow.n_channels = nchannels(Dfinal);
        candidateRow.n_samples = nsamples(Dfinal);
        candidateRow.n_trials = ntrials(Dfinal);
        candidateRow.subject_id = string(subjectID);
        candidateRow.group = string(groupName);
        candidateRow.condition = string(condition);
        candidateRow.final_epoched_mat = string(Dfile);
        candidateRow.global_std_uV = finalStats.stdVal;
        candidateRow.global_median_abs_uV = finalStats.medianAbs;
        candidateRow.global_p95_abs_uV = finalStats.p95Abs;
        candidateRow.global_p99_abs_uV = finalStats.p99Abs;
        candidateRow.global_max_abs_uV = finalStats.maxAbs;
        candidateRow.trial_peak2peak_median_uV = cand.trialP2PMedian;
        candidateRow.trial_peak2peak_p75_uV = cand.trialP2PP75;
        candidateRow.trial_peak2peak_p90_uV = cand.trialP2PP90;
        candidateRow.trial_peak2peak_p95_uV = cand.trialP2PP95;
        candidateRow.trial_peak2peak_max_uV = cand.trialP2PMax;
        candidateRow.trial_maxabs_median_uV = cand.trialMaxAbsMedian;
        candidateRow.trial_maxabs_p95_uV = cand.trialMaxAbsP95;
        candidateRow.jump_absdiff_p95_uV = cand.jumpP95;
        candidateRow.jump_absdiff_p99_uV = cand.jumpP99;
        candidateRow.jump_absdiff_max_uV = cand.jumpMax;
        candidateRows = [candidateRows; candidateRow]; %#ok<AGROW>

        gridRows = addGridRows(gridRows, subjectID, groupName, condition, Dfile, ...
            cand.trialP2P, cand.trialMaxAbs, cand.jumpTrialMax, cfg);

        outRow = table();
        outRow.n_channels = nchannels(Dfinal);
        outRow.fs = fsample(Dfinal);
        outRow.n_samples_per_trial = nsamples(Dfinal);
        outRow.n_trials = ntrials(Dfinal);
        outRow.subject_id = string(subjectID);
        outRow.group = string(groupName);
        outRow.condition = string(condition);
        outRow.input_bdf = string(bdfFile);
        outRow.input_json = string(jsonFile);
        outRow.input_channels = string(channelsFile);
        % Compatibility aliases for old C-summary readers. These now point
        % to BDF/sidecars, not BrainVision files.
        outRow.input_vhdr = string(bdfFile);
        outRow.input_eeg = string(bdfFile);
        outRow.output_dir = string(subjOutDir);
        outRow.import_scale = cfg.scaleMultiplierToUV;
        outRow.import_spm_mat = string(importMat);
        outRow.final_epoched_mat = string(Dfile);
        outRow.final_std_uV = finalStats.stdVal;
        outRow.final_median_abs_uV = finalStats.medianAbs;
        outRow.final_p95_abs_uV = finalStats.p95Abs;
        outRow.final_p99_abs_uV = finalStats.p99Abs;
        outRow.status = "OK";
        outRow.error_message = "";
        summaryRows = [summaryRows; outRow]; %#ok<AGROW>

        fprintf('SUCCESS | %s %s %s | final std %.4g | p95 %.4g | trials %d\n', ...
            subjectID, groupName, condition, finalStats.stdVal, finalStats.p95Abs, ntrials(Dfinal));

    catch ME
        fprintf('\nERROR | %s | %s | %s\n', subjectID, groupName, condition);
        fprintf('%s\n', ME.message);

        outRow = table();
        outRow.subject_id = string(subjectID);
        outRow.group = string(groupName);
        outRow.condition = string(condition);
        outRow.input_bdf = string(bdfFile);
        outRow.input_json = string(jsonFile);
        outRow.input_channels = string(channelsFile);
        outRow.input_vhdr = string(bdfFile);
        outRow.input_eeg = string(bdfFile);
        outRow.output_dir = string(subjOutDir);
        outRow.import_scale = cfg.scaleMultiplierToUV;
        outRow.import_spm_mat = "";
        outRow.final_epoched_mat = "";
        outRow.n_channels = NaN;
        outRow.fs = NaN;
        outRow.n_samples_per_trial = NaN;
        outRow.n_trials = NaN;
        outRow.final_std_uV = NaN;
        outRow.final_median_abs_uV = NaN;
        outRow.final_p95_abs_uV = NaN;
        outRow.final_p99_abs_uV = NaN;
        outRow.status = "ERROR";
        outRow.error_message = string(ME.message);
        summaryRows = [summaryRows; outRow]; %#ok<AGROW>
    end
end

%% -------------------------------------------------------------------------
% Save outputs - filenames unchanged
% -------------------------------------------------------------------------

summaryTSV = fullfile(outRoot, 'C_import_and_artifact_scaling_summary.tsv');
stageCSV   = fullfile(outRoot, 'C_stagewise_amplitude_stats.csv');
candCSV    = fullfile(outRoot, 'C_threshold_candidate_stats.csv');
gridCSV    = fullfile(outRoot, 'C_threshold_rejection_grid.csv');

writetable(summaryRows, summaryTSV, 'FileType','text', 'Delimiter','\t', 'WriteVariableNames', true);
writetable(stageRows, stageCSV);
writetable(candidateRows, candCSV);
writetable(gridRows, gridCSV);

fprintf('\n============================================================\n');
fprintf('Saved summary:          %s\n', summaryTSV);
fprintf('Saved stage stats:      %s\n', stageCSV);
fprintf('Saved candidate stats:  %s\n', candCSV);
fprintf('Saved threshold grid:   %s\n', gridCSV);
fprintf('OK:    %d\n', sum(summaryRows.status == "OK"));
fprintf('ERROR: %d\n', sum(summaryRows.status == "ERROR"));
fprintf('============================================================\n');

if ~isempty(candidateRows)
    fprintf('\n===== COHORT THRESHOLD GUIDANCE FROM C OUTPUTS =====\n');
    fprintf('Median final std:        %.4g uV\n', median(candidateRows.global_std_uV, 'omitnan'));
    fprintf('Median final p95 abs:    %.4g uV\n', median(candidateRows.global_p95_abs_uV, 'omitnan'));
    fprintf('Median trial P2P p95:    %.4g uV\n', median(candidateRows.trial_peak2peak_p95_uV, 'omitnan'));
    fprintf('Median jump p99:         %.4g uV\n', median(candidateRows.jump_absdiff_p99_uV, 'omitnan'));
    fprintf('\nUse C_threshold_rejection_grid.csv to choose D thresholds that reject\n');
    fprintf('a controlled proportion of trials rather than guessing fixed values.\n');
end

diary off;

%% =========================================================================
% Helpers
% =========================================================================

function ftdata = readTDBRAINBDFAsFieldTrip(bdfFile, scaleMultiplierToUV)

    hdr = ft_read_header(bdfFile);
    labels = string(hdr.label(:));

    % Drop BioSemi Status channel and possible annotation/status-like signals.
    drop = strcmpi(labels, "Status") | ...
           contains(lower(labels), "status") | ...
           contains(lower(labels), "annotation") | ...
           contains(lower(labels), "annotations");

    keepIdx = find(~drop);

    if isempty(keepIdx)
        error('No channels remain after dropping Status/annotation channels: %s', bdfFile);
    end

    fprintf('\nImported BDF:\n');
    fprintf('Channels in file : %d\n', numel(labels));
    fprintf('Status dropped   : %d\n', sum(drop));
    fprintf('Imported         : %d\n', numel(keepIdx));
    fprintf('Sampling rate    : %.1f Hz\n', hdr.Fs);
    
    disp(table(labels,drop))
    X = ft_read_data(bdfFile, 'chanindx', keepIdx);
    X = double(X) .* scaleMultiplierToUV;

    ftdata = [];
    ftdata.label   = cellstr(labels(keepIdx));
    ftdata.fsample = double(hdr.Fs);
    ftdata.trial   = {X};
    ftdata.time    = {(0:size(X,2)-1) ./ double(hdr.Fs)};

end

function Dfile = runSPMChannelTypePrepare(Dfile, eegChanFile, eogChanFile, otherChanFile)

    clear matlabbatch;
    matlabbatch{1}.spm.meeg.preproc.prepare.D = {Dfile};

    taskN = 1;

    % Conservative default reset.
    matlabbatch{1}.spm.meeg.preproc.prepare.task{taskN}.defaulttype = 1;
    taskN = taskN + 1;

    if isfile(otherChanFile)
        matlabbatch{1}.spm.meeg.preproc.prepare.task{taskN}.settype.channels{1}.chanfile = {otherChanFile};
        matlabbatch{1}.spm.meeg.preproc.prepare.task{taskN}.settype.newtype = 'Other';
        taskN = taskN + 1;
    else
        warning('Missing OTHER channel selection file: %s', otherChanFile);
    end

    if isfile(eogChanFile)
        matlabbatch{1}.spm.meeg.preproc.prepare.task{taskN}.settype.channels{1}.chanfile = {eogChanFile};
        matlabbatch{1}.spm.meeg.preproc.prepare.task{taskN}.settype.newtype = 'EOG';
        taskN = taskN + 1;
    else
        warning('Missing EOG channel selection file: %s', eogChanFile);
    end

    if isfile(eegChanFile)
        matlabbatch{1}.spm.meeg.preproc.prepare.task{taskN}.settype.channels{1}.chanfile = {eegChanFile};
        matlabbatch{1}.spm.meeg.preproc.prepare.task{taskN}.settype.newtype = 'EEG';
    else
        warning('Missing EEG channel selection file: %s', eegChanFile);
    end

    spm_jobman('run', matlabbatch);
end

function deleteIfExists(f)
    if isfile(f)
        delete(f);
    end
end

function out = prefixedMat(inMat, prefix)
    [folder, base, ext] = fileparts(inMat);
    out = fullfile(folder, [prefix base ext]);
    if ~isfile(out)
        d = dir(fullfile(folder, [prefix '*.mat']));
        keep = true(size(d));
        for k = 1:numel(d)
            keep(k) = ~strcmpi(d(k).name, 'avref_montage.mat');
        end
        d = d(keep);
        if isempty(d)
            error('Expected prefixed output not found: %s', out);
        end
        [~, idx] = max([d.datenum]);
        out = fullfile(d(idx).folder, d(idx).name);
    end
end


function Dfile = runSPMDownsample(Dfile, targetFs)
    % Downsample continuous M/EEG data using SPM's downsample module.
    % This should be called after low-pass filtering to minimise aliasing.

    D = spm_eeg_load(Dfile);
    currentFs = fsample(D);

    if abs(currentFs - targetFs) < 1e-6
        fprintf('Downsample skipped: current fs already %.4g Hz\n', currentFs);
        return;
    end

    if currentFs < targetFs
        error('Cannot downsample from %.4g Hz to higher target %.4g Hz', currentFs, targetFs);
    end

    [folder, base, ext] = fileparts(Dfile);
    expected = fullfile(folder, ['d' base ext]);
    deleteIfExists(expected);
    deleteIfExists(strrep(expected, '.mat', '.dat'));

    clear matlabbatch;
    matlabbatch{1}.spm.meeg.preproc.downsample.D = {Dfile};
    matlabbatch{1}.spm.meeg.preproc.downsample.fsample_new = targetFs;
    matlabbatch{1}.spm.meeg.preproc.downsample.prefix = 'd';

    fprintf('Downsampling %.4g Hz -> %.4g Hz\n', currentFs, targetFs);
    spm_jobman('run', matlabbatch);

    Dfile = prefixedMat(Dfile, 'd');

    Dnew = spm_eeg_load(Dfile);
    fprintf('Downsample complete: fs %.4g Hz, samples %d, trials %d\n', ...
        fsample(Dnew), nsamples(Dnew), ntrials(Dnew));
end

function Dfile = runEpochWithFallback(Dfile, epoch_ms, conditionLabel)
    [folder, base, ext] = fileparts(Dfile);
    expected = fullfile(folder, ['e' base ext]);
    deleteIfExists(expected);
    deleteIfExists(strrep(expected, '.mat', '.dat'));

    methods = {'trialength', 'triallength', 'length'};
    lastME = [];

    for m = 1:numel(methods)
        try
            clear matlabbatch;
            matlabbatch{1}.spm.meeg.preproc.epoch.D = {Dfile};
            switch methods{m}
                case 'trialength'
                    matlabbatch{1}.spm.meeg.preproc.epoch.trialchoice.arbitrary.trialength = epoch_ms;
                case 'triallength'
                    matlabbatch{1}.spm.meeg.preproc.epoch.trialchoice.arbitrary.triallength = epoch_ms;
                case 'length'
                    matlabbatch{1}.spm.meeg.preproc.epoch.trialchoice.arbitrary.length = epoch_ms;
            end
            matlabbatch{1}.spm.meeg.preproc.epoch.trialchoice.arbitrary.conditionlabel = conditionLabel;
            matlabbatch{1}.spm.meeg.preproc.epoch.bc = 1;
            matlabbatch{1}.spm.meeg.preproc.epoch.eventpadding = 0;
            matlabbatch{1}.spm.meeg.preproc.epoch.prefix = 'e';

            fprintf('Trying SPM arbitrary epoch field: %s\n', methods{m});
            spm_jobman('run', matlabbatch);
            Dfile = prefixedMat(Dfile, 'e');
            return;
        catch ME
            lastME = ME;
            fprintf('Epoch attempt failed using field "%s": %s\n', methods{m}, ME.message);
        end
    end

    error('All SPM arbitrary epoch attempts failed. Last error: %s', lastME.message);
end

function rows = addStageRow(rows, subjectID, groupName, condition, stageName, Dfile)
    try
        D = spm_eeg_load(Dfile);
        s = quickStatsSafe(D);
        r = table();
        r.subject_id = string(subjectID);
        r.group = string(groupName);
        r.condition = string(condition);
        r.stage = string(stageName);
        r.mat_file = string(Dfile);
        r.n_channels = nchannels(D);
        r.n_samples = nsamples(D);
        r.n_trials = ntrials(D);
        r.std_uV = s.stdVal;
        r.median_abs_uV = s.medianAbs;
        r.p95_abs_uV = s.p95Abs;
        r.p99_abs_uV = s.p99Abs;
        r.max_abs_uV = s.maxAbs;
        r.status = "OK";
        r.error_message = "";
    catch ME
        r = table();
        r.subject_id = string(subjectID);
        r.group = string(groupName);
        r.condition = string(condition);
        r.stage = string(stageName);
        r.mat_file = string(Dfile);
        r.n_channels = NaN;
        r.n_samples = NaN;
        r.n_trials = NaN;
        r.std_uV = NaN;
        r.median_abs_uV = NaN;
        r.p95_abs_uV = NaN;
        r.p99_abs_uV = NaN;
        r.max_abs_uV = NaN;
        r.status = "ERROR";
        r.error_message = string(ME.message);
    end
    rows = [rows; r]; %#ok<AGROW>

    fprintf('  %-28s | std %.5g | medAbs %.5g | p95 %.5g | maxAbs %.5g | trials %.0f\n', ...
        stageName, r.std_uV, r.median_abs_uV, r.p95_abs_uV, r.max_abs_uV, r.n_trials);
end

function stats = quickStatsSafe(D)
    eegIdx = getEEGChannelIdx(D);
    nSamp = nsamples(D);
    nTrial = ntrials(D);

    vals = [];
    for tr = 1:nTrial
        X = double(D(eegIdx, 1:nSamp, tr));
        vals = [vals; X(:)]; %#ok<AGROW>
    end

    vals = vals(isfinite(vals));
    ax = abs(vals);

    stats = struct();
    stats.stdVal = std(vals, 'omitnan');
    stats.medianAbs = median(ax, 'omitnan');
    stats.p95Abs = prctile(ax, 95);
    stats.p99Abs = prctile(ax, 99);
    stats.maxAbs = max(ax);
end

function eegIdx = getEEGChannelIdx(D)
    labels = string(D.chanlabels);
    labels = labels(:);

    scalpEEG = ["Fp1","Fp2","F7","F3","Fz","F4","F8", ...
                "FC3","FCz","FC4","T7","C3","Cz","C4","T8", ...
                "CP3","CPz","CP4","P7","P3","Pz","P4","P8", ...
                "O1","Oz","O2"];

    eegIdx = find(ismember(upper(labels), upper(scalpEEG)));

    if isempty(eegIdx)
        try
            types = string(D.chantype(:));
            eegIdx = find(strcmpi(types, "EEG"));
        catch
            eegIdx = 1:nchannels(D);
        end
    end
end

function cand = thresholdCandidateStats(D)
    eegIdx = getEEGChannelIdx(D);
    nSamp = nsamples(D);
    nTrial = ntrials(D);

    trialP2P = nan(nTrial,1);
    trialMaxAbs = nan(nTrial,1);
    jumpTrialMax = nan(nTrial,1);
    allJump = [];

    for tr = 1:nTrial
        X = double(D(eegIdx, 1:nSamp, tr));
        trialP2P(tr) = max(max(X,[],2) - min(X,[],2));
        trialMaxAbs(tr) = max(abs(X(:)));
        dX = abs(diff(X,1,2));
        jumpTrialMax(tr) = max(dX(:));
        allJump = [allJump; dX(:)]; %#ok<AGROW>
    end

    allJump = allJump(isfinite(allJump));

    cand = struct();
    cand.trialP2P = trialP2P;
    cand.trialMaxAbs = trialMaxAbs;
    cand.jumpTrialMax = jumpTrialMax;

    cand.trialP2PMedian = median(trialP2P, 'omitnan');
    cand.trialP2PP75 = prctile(trialP2P, 75);
    cand.trialP2PP90 = prctile(trialP2P, 90);
    cand.trialP2PP95 = prctile(trialP2P, 95);
    cand.trialP2PMax = max(trialP2P);

    cand.trialMaxAbsMedian = median(trialMaxAbs, 'omitnan');
    cand.trialMaxAbsP95 = prctile(trialMaxAbs, 95);

    cand.jumpP95 = prctile(allJump, 95);
    cand.jumpP99 = prctile(allJump, 99);
    cand.jumpMax = max(allJump);
end

function rows = addGridRows(rows, subjectID, groupName, condition, Dfile, trialP2P, trialMaxAbs, jumpTrialMax, cfg)
    nTrial = numel(trialP2P);

    for th = cfg.candidate_peak2peak_uV
        r = makeGridRow(subjectID, groupName, condition, Dfile, 'peak2peak_trial', th, ...
            sum(trialP2P > th), nTrial);
        rows = [rows; r]; %#ok<AGROW>
    end

    for th = cfg.candidate_maxabs_uV
        r = makeGridRow(subjectID, groupName, condition, Dfile, 'maxabs_trial', th, ...
            sum(trialMaxAbs > th), nTrial);
        rows = [rows; r]; %#ok<AGROW>
    end

    for th = cfg.candidate_jump_uV
        r = makeGridRow(subjectID, groupName, condition, Dfile, 'jump_trialmax', th, ...
            sum(jumpTrialMax > th), nTrial);
        rows = [rows; r]; %#ok<AGROW>
    end
end

function r = makeGridRow(subjectID, groupName, condition, Dfile, metric, threshold, nReject, nTrial)
    r = table();
    r.subject_id = string(subjectID);
    r.group = string(groupName);
    r.condition = string(condition);
    r.final_epoched_mat = string(Dfile);
    r.metric = string(metric);
    r.threshold_uV = threshold;
    r.n_trials = nTrial;
    r.estimated_rejected_trials = nReject;
    r.estimated_rejected_fraction = nReject ./ max(nTrial,1);
end

function verifyTDBRAINChannelTypes(Dfile, beforeMontage)

    D = spm_eeg_load(Dfile);

    types = string(D.chantype(:));
    types = types(:);

    nEEG   = sum(strcmpi(types,'EEG'));
    nEOG   = sum(strcmpi(types,'EOG'));
    nOther = sum(strcmpi(types,'Other'));

    fprintf('\nCHANNEL TYPE QA | %s\n', Dfile);
    fprintf('EEG   = %d\n', nEEG);
    fprintf('EOG   = %d\n', nEOG);
    fprintf('Other = %d\n', nOther);
    if beforeMontage
        if nEEG ~= 26
            error('Channel typing failed: expected 26 EEG, found %d', nEEG);
        end

        if nEOG ~= 4
            error('Channel typing failed: expected 4 EOG (V3.1), found %d', nEOG);
        end
        if nOther ~= 2
            error('Channel typing failed: expected 2 Other, found %d', nOther);
        end
    else
        if nEEG ~= 26
            error('Channel typing failed: expected 26 EEG, found %d', nEEG);
        end

        if nEOG ~= 0
            error('Channel typing failed: expected 0 EOG, found %d', nEOG);
        end

        if nOther ~= 0
            error('Channel typing failed: expected 0 Other, found %d', nOther);
        end
    end
end
