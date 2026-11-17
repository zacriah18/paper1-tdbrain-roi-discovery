%% =========================================================================
% D_artifact_reject_shortlist.m
%
% D-stage artifact rejection for the revised TDBRAIN EEG DCM pipeline.
%
% Assumes C is locked:
%   C_import_and_artifact_scaling.m
%       - scale=1 import
%       - channel typing before montage
%       - 0.5 Hz high-pass
%       - EEG-only average reference, dropping EOG/Other
%       - 48 Hz low-pass
%       - 4 s epoching
%       - NO trial rejection
%
% D performs ONLY trial rejection/removal on the final C epoched files.
%
% Primary rejection rule:
%   Reject trial if >=1 EEG channel has peak-to-peak >1000 uV.
%
% Rationale:
%   DCM/source inversion uses the full multichannel EEG pattern, so a single
%   severely corrupted EEG channel contaminates the whole trial/epoch.
%
% Secondary transient guard:
%   Reject trial if >=1 EEG channel has max point-to-point jump >50 uV.
%
% Rationale:
%   Captures sharp single-channel or neighbouring-channel transients,
%   including muscle twitches, cable pops, and abrupt movement artefacts.
%
% Current:
%   cfg.use_jump_guard = true
%   cfg.jump_threshold_uV = 100
%
% Default:
%   cfg.use_jump_guard = false
%
% Outputs:
%   derivatives/D_artifact_reject_shortlist/
%       D_artifact_reject_shortlist_summary.csv
%       D_artifact_reject_trial_flags.csv
%       D_artifact_reject_stage_stats.csv
%       D_artifact_reject_log.txt
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

% Primary locked C-audit-derived criterion.
cfg.p2p_threshold_uV = 1000;
cfg.channel_fraction_cutoff = 0.00;

% With channel_fraction_cutoff = 0,
% reject if >=1 EEG channel exceeds threshold.
cfg.reject_if_fraction_strictly_greater = true;

% Optional secondary severe transient guard.
cfg.use_jump_guard = true;
cfg.jump_threshold_uV = 50;

% Optional sensitivity override. The default remains the locked 50 uV
% primary analysis. A separate output name is mandatory when overriding so
% the primary derivative can never be overwritten.
envJumpThreshold = str2double(getenv('TDBRAIN_D_JUMP_THRESHOLD_UV'));
envOutputName = strtrim(getenv('TDBRAIN_D_OUTPUT_NAME'));
if isfinite(envJumpThreshold) && envJumpThreshold > 0
    if isempty(envOutputName)
        error('Sensitivity jump-threshold override requires TDBRAIN_D_OUTPUT_NAME.');
    end
    cfg.jump_threshold_uV = envJumpThreshold;
end

% Minimum retention guard for source reconstruction/DCM.
cfg.min_good_trials_warn = 20;
cfg.min_good_trials_error = 10;

% If true, remove rejected trials and save final rD file.
% If false, only generate flags/summaries.
cfg.remove_rejected_trials = true;

% Expected channel count after C montage.
cfg.expected_EEG_channels = 26;
cfg.expected_EOG_channels = 0;
cfg.expected_Other_channels = 0;

cRoot = fullfile(rootDir, 'derivatives', 'C_import_and_artifact_scaling');
inSummary = fullfile(cRoot, 'C_import_and_artifact_scaling_summary.tsv');

if isempty(envOutputName)
    envOutputName = 'D_artifact_reject_shortlist';
end
if contains(envOutputName,filesep) || contains(envOutputName,'/') || contains(envOutputName,'..')
    error('TDBRAIN_D_OUTPUT_NAME must be one derivative-folder name.');
end
outRoot = fullfile(rootDir, 'derivatives', envOutputName);
if ~exist(outRoot, 'dir'), mkdir(outRoot); end

logFile = fullfile(outRoot, 'D_artifact_reject_log.txt');
diary(logFile);

fprintf('\n============================================================\n');
fprintf('D ARTIFACT REJECT SHORTLIST\n');
fprintf('Input C summary : %s\n', inSummary);
fprintf('Output root     : %s\n', outRoot);
fprintf('Primary rule    : reject trial if >%.1f%% EEG channels have P2P > %.1f uV\n', ...
    100*cfg.channel_fraction_cutoff, cfg.p2p_threshold_uV);
fprintf('Jump guard      : %d | threshold %.1f uV\n', cfg.use_jump_guard, cfg.jump_threshold_uV);
fprintf('Remove trials   : %d\n', cfg.remove_rejected_trials);
fprintf('============================================================\n\n');

if ~isfile(inSummary)
    error('Missing C summary file: %s', inSummary);
end

T = readtable(inSummary, ...
    'FileType','text', ...
    'Delimiter','\t', ...
    'VariableNamingRule','preserve');

disp(T.Properties.VariableNames')

subjectVar = findVar(T, {'subject_id','subjectid','subject'});
groupVar   = findVar(T, {'group'});
condVar    = findVar(T, {'condition'});
statusVar  = findVar(T, {'status'});
cFinalVar  = findVar(T, {'final_epoched_mat','finalepochedmat','final_c_epoched_mat'});

T.subject_id = string(T.(subjectVar));
T.group = string(T.(groupVar));
T.condition = string(T.(condVar));
T.status = string(T.(statusVar));
T.final_epoched_mat = string(T.(cFinalVar));

T = T(T.status == "OK" & strlength(T.final_epoched_mat) > 0, :);

% TEST MODE:
% T = T(1:4,:);

summaryRows = table();
trialFlagRows = table();
stageRows = table();

%% -------------------------------------------------------------------------
% Main loop
% -------------------------------------------------------------------------

for i = 1:height(T)

    subjectID = char(T.subject_id(i));
    groupName = char(T.group(i));
    condition = char(T.condition(i));
    inputMat = char(T.final_epoched_mat(i));

    subjOutDir = fullfile(outRoot, groupName, condition, subjectID);
    if ~exist(subjOutDir, 'dir'), mkdir(subjOutDir); end

    fprintf('\n============================================================\n');
    fprintf('%03d/%03d | %s | %s | %s\n', ...
        i, height(T), subjectID, groupName, condition);
    fprintf('Input C epoched file: %s\n', inputMat);
    fprintf('D output dir        : %s\n', subjOutDir);
    fprintf('============================================================\n');

    try
        if ~isfile(inputMat)
            error('Missing C epoched SPM file: %s', inputMat);
        end

        %% Copy C epoched SPM pair into D derivative folder
        localMat = copySpmPairToDir(inputMat, subjOutDir);
        D = spm_eeg_load(localMat);

        verifyPostCChannelTypes(D, cfg);

        startStats = quickStatsEEG(D);
        stageRows = [stageRows; makeStageRow(subjectID, groupName, condition, ...
            "D00_input_from_C", localMat, D, startStats)]; %#ok<AGROW>

        fprintf('Input trials: %d | EEG channels: %d | std %.3f | p95 %.3f | max %.3f\n', ...
            ntrials(D), numel(getEEGIdx(D)), startStats.stdVal, startStats.p95Abs, startStats.maxAbs);

        %% Compute trial metrics and flags
        [trialMetrics, rejectInfo] = computeTrialFlags(D, cfg);

        trialRows = table();
        nTrial = ntrials(D);

        trialRows.subject_id = repmat(string(subjectID), nTrial, 1);
        trialRows.group = repmat(string(groupName), nTrial, 1);
        trialRows.condition = repmat(string(condition), nTrial, 1);
        trialRows.input_c_epoched_mat = repmat(string(inputMat), nTrial, 1);
        trialRows.local_d_input_mat = repmat(string(localMat), nTrial, 1);
        trialRows.trial_index = (1:nTrial)';
        trialRows.n_eeg_channels = repmat(rejectInfo.nEEG, nTrial, 1);
        trialRows.n_channels_required_for_reject = repmat(rejectInfo.nChannelsRequired, nTrial, 1);

        trialRows.p2p_threshold_uV = repmat(cfg.p2p_threshold_uV, nTrial, 1);
        trialRows.p2p_n_channels_exceeding = trialMetrics.p2pNChannelsExceeding(:);
        trialRows.p2p_fraction_channels_exceeding = trialMetrics.p2pFractionChannelsExceeding(:);
        trialRows.p2p_trial_max_uV = trialMetrics.p2pTrialMax(:);
        trialRows.p2p_trial_p95_channel_uV = trialMetrics.p2pTrialP95Channel(:);
        trialRows.reject_p2p = rejectInfo.rejectP2P(:);

        trialRows.jump_guard_enabled = repmat(cfg.use_jump_guard, nTrial, 1);
        trialRows.jump_threshold_uV = repmat(cfg.jump_threshold_uV, nTrial, 1);
        trialRows.jump_n_channels_exceeding = trialMetrics.jumpNChannelsExceeding(:);
        trialRows.jump_fraction_channels_exceeding = trialMetrics.jumpFractionChannelsExceeding(:);
        trialRows.jump_trial_max_uV = trialMetrics.jumpTrialMax(:);
        trialRows.jump_trial_p95_channel_uV = trialMetrics.jumpTrialP95Channel(:);
        trialRows.reject_jump = rejectInfo.rejectJump(:);

        trialRows.reject_final = rejectInfo.rejectFinal(:);

        trialFlagRows = [trialFlagRows; trialRows]; %#ok<AGROW>

        %% Apply bad-trial marks and remove
        rejectedTrials = find(rejectInfo.rejectFinal(:))';
        nRejected = numel(rejectedTrials);
        nGood = nTrial - nRejected;
        rejectionFraction = nRejected / max(nTrial,1);

        fprintf('Rejected trials: %d/%d (%.2f%%) | good=%d\n', ...
            nRejected, nTrial, 100*rejectionFraction, nGood);

        qcFlag = "OK";
        if nGood < cfg.min_good_trials_warn
            qcFlag = "LOW_TRIAL_COUNT_REVIEW";
        end
        if nGood < cfg.min_good_trials_error
            qcFlag = "LOW_TRIAL_COUNT_ERROR";
        end

        finalMat = string(localMat);
        markedMat = string(localMat);
        removedMat = "";

        if ~isempty(rejectedTrials)
            Dmarked = D;
            Dmarked = badtrials(Dmarked, rejectedTrials, 1);
            save(Dmarked);
            markedMat = string(fullfile(Dmarked.path, Dmarked.fname));

            if cfg.remove_rejected_trials
                clear matlabbatch;
                matlabbatch{1}.spm.meeg.preproc.remove.D = {char(markedMat)};
                matlabbatch{1}.spm.meeg.preproc.remove.prefix = 'r';

                spm_jobman('run', matlabbatch);

                removedMat = string(newestMat(subjOutDir));
                finalMat = removedMat;
            else
                finalMat = markedMat;
            end
        else
            finalMat = string(copySpmPairWithPrefix(localMat, subjOutDir, 'Dclean_'));
        end

        Dfinal = spm_eeg_load(char(finalMat));
        finalStats = quickStatsEEG(Dfinal);
        stageRows = [stageRows; makeStageRow(subjectID, groupName, condition, ...
            "D01_after_rejection", char(finalMat), Dfinal, finalStats)]; %#ok<AGROW>

        %% Summary row
        outRow = table();
        outRow.subject_id = string(subjectID);
        outRow.group = string(groupName);
        outRow.condition = string(condition);
        outRow.input_c_epoched_mat = string(inputMat);
        outRow.local_d_input_mat = string(localMat);
        outRow.marked_mat = markedMat;
        outRow.final_clean_mat = finalMat;
        outRow.n_eeg_channels = rejectInfo.nEEG;
        outRow.n_trials_before = nTrial;
        outRow.n_trials_rejected_p2p = sum(rejectInfo.rejectP2P);
        outRow.n_trials_rejected_jump = sum(rejectInfo.rejectJump);
        outRow.n_trials_rejected_total = nRejected;
        outRow.n_trials_good = nGood;
        outRow.rejection_fraction = rejectionFraction;
        outRow.p2p_threshold_uV = cfg.p2p_threshold_uV;
        outRow.channel_fraction_cutoff = cfg.channel_fraction_cutoff;
        outRow.n_channels_required_for_reject = rejectInfo.nChannelsRequired;
        outRow.jump_guard_enabled = cfg.use_jump_guard;
        outRow.jump_threshold_uV = cfg.jump_threshold_uV;
        outRow.start_std_uV = startStats.stdVal;
        outRow.start_p95_abs_uV = startStats.p95Abs;
        outRow.start_max_abs_uV = startStats.maxAbs;
        outRow.final_std_uV = finalStats.stdVal;
        outRow.final_p95_abs_uV = finalStats.p95Abs;
        outRow.final_max_abs_uV = finalStats.maxAbs;
        outRow.qc_flag = qcFlag;
        outRow.status = "OK";
        outRow.error_message = "";

        summaryRows = [summaryRows; outRow]; %#ok<AGROW>

        fprintf('SUCCESS | %s %s | good %d/%d | QC %s\n', ...
            subjectID, condition, nGood, nTrial, qcFlag);

    catch ME

        fprintf('\nERROR: %s %s\n', subjectID, condition);
        fprintf('%s\n', ME.message);

        outRow = table();
        outRow.subject_id = string(subjectID);
        outRow.group = string(groupName);
        outRow.condition = string(condition);
        outRow.input_c_epoched_mat = string(inputMat);
        outRow.local_d_input_mat = "";
        outRow.marked_mat = "";
        outRow.final_clean_mat = "";
        outRow.n_eeg_channels = NaN;
        outRow.n_trials_before = NaN;
        outRow.n_trials_rejected_p2p = NaN;
        outRow.n_trials_rejected_jump = NaN;
        outRow.n_trials_rejected_total = NaN;
        outRow.n_trials_good = NaN;
        outRow.rejection_fraction = NaN;
        outRow.p2p_threshold_uV = cfg.p2p_threshold_uV;
        outRow.channel_fraction_cutoff = cfg.channel_fraction_cutoff;
        outRow.n_channels_required_for_reject = NaN;
        outRow.jump_guard_enabled = cfg.use_jump_guard;
        outRow.jump_threshold_uV = cfg.jump_threshold_uV;
        outRow.start_std_uV = NaN;
        outRow.start_p95_abs_uV = NaN;
        outRow.start_max_abs_uV = NaN;
        outRow.final_std_uV = NaN;
        outRow.final_p95_abs_uV = NaN;
        outRow.final_max_abs_uV = NaN;
        outRow.qc_flag = "ERROR";
        outRow.status = "ERROR";
        outRow.error_message = string(ME.message);

        summaryRows = [summaryRows; outRow]; %#ok<AGROW>
    end
end

%% -------------------------------------------------------------------------
% Save outputs
% -------------------------------------------------------------------------

summaryCSV = fullfile(outRoot, 'D_artifact_reject_shortlist_summary.csv');
trialFlagsCSV = fullfile(outRoot, 'D_artifact_reject_trial_flags.csv');
stageStatsCSV = fullfile(outRoot, 'D_artifact_reject_stage_stats.csv');

writetable(summaryRows, summaryCSV);
writetable(trialFlagRows, trialFlagsCSV);
writetable(stageRows, stageStatsCSV);

fprintf('\n============================================================\n');
fprintf('Saved summary    : %s\n', summaryCSV);
fprintf('Saved trial flags: %s\n', trialFlagsCSV);
fprintf('Saved stage stats: %s\n', stageStatsCSV);
fprintf('OK:              : %d\n', sum(summaryRows.status == "OK"));
fprintf('ERROR:           : %d\n', sum(summaryRows.status == "ERROR"));

if any(summaryRows.status == "OK")
    ok = summaryRows.status == "OK";
    fprintf('\nRetention summary across OK files:\n');
    fprintf('Median good trials    : %.2f\n', median(summaryRows.n_trials_good(ok), 'omitnan'));
    fprintf('Median rejected trials: %.2f\n', median(summaryRows.n_trials_rejected_total(ok), 'omitnan'));
    fprintf('Mean rejection frac   : %.4f\n', mean(summaryRows.rejection_fraction(ok), 'omitnan'));
    fprintf('Median rejection frac : %.4f\n', median(summaryRows.rejection_fraction(ok), 'omitnan'));
    fprintf('P90 rejection frac    : %.4f\n', prctile(summaryRows.rejection_fraction(ok), 90));
    fprintf('Files <20 good trials : %d\n', sum(summaryRows.n_trials_good(ok) < cfg.min_good_trials_warn));
    fprintf('Files <10 good trials : %d\n', sum(summaryRows.n_trials_good(ok) < cfg.min_good_trials_error));
end

fprintf('============================================================\n');
fprintf('D_artifact_reject_shortlist finished\n');
fprintf('============================================================\n');

diary off;

%% =========================================================================
% Helpers
% =========================================================================

function localMat = copySpmPairToDir(inputMat, dstDir)

    [~, base, ~] = fileparts(inputMat);
    inputDat = replace(inputMat, '.mat', '.dat');

    localMat = fullfile(dstDir, [base '.mat']);
    localDat = fullfile(dstDir, [base '.dat']);

    copyfile(inputMat, localMat);

    if isfile(inputDat)
        copyfile(inputDat, localDat);
    else
        warning('No matching .dat file found for %s', inputMat);
    end
end

function outMat = copySpmPairWithPrefix(inputMat, dstDir, prefix)

    [~, base, ~] = fileparts(inputMat);
    inputDat = replace(inputMat, '.mat', '.dat');

    outMat = fullfile(dstDir, [prefix base '.mat']);
    outDat = fullfile(dstDir, [prefix base '.dat']);

    copyfile(inputMat, outMat);

    if isfile(inputDat)
        copyfile(inputDat, outDat);
    else
        warning('No matching .dat file found for %s', inputMat);
    end
end

function Dfile = newestMat(folder)

    mats = dir(fullfile(folder, '*.mat'));

    if isempty(mats)
        error('No .mat files found in %s', folder);
    end

    [~, idx] = max([mats.datenum]);
    Dfile = fullfile(mats(idx).folder, mats(idx).name);
end

function verifyPostCChannelTypes(D, cfg)

    types = string(D.chantype);
    types = types(:);

    nEEG = sum(strcmpi(types, 'EEG'));
    nEOG = sum(strcmpi(types, 'EOG'));
    nOther = sum(strcmpi(types, 'Other'));

    fprintf('CHANNEL QA | EEG=%d EOG=%d Other=%d\n', nEEG, nEOG, nOther);

    if nEEG ~= cfg.expected_EEG_channels
        error('Expected %d EEG channels after C montage, found %d.', ...
            cfg.expected_EEG_channels, nEEG);
    end

    if nEOG ~= cfg.expected_EOG_channels
        error('Expected %d EOG channels after C montage, found %d.', ...
            cfg.expected_EOG_channels, nEOG);
    end

    if nOther ~= cfg.expected_Other_channels
        error('Expected %d Other channels after C montage, found %d.', ...
            cfg.expected_Other_channels, nOther);
    end
end

function eegIdx = getEEGIdx(D)

    types = string(D.chantype);
    types = types(:);
    eegIdx = find(strcmpi(types, 'EEG'));

    if isempty(eegIdx)
        error('No EEG channels found.');
    end
end

function stats = quickStatsEEG(D)

    eegIdx = getEEGIdx(D);
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

function row = makeStageRow(subjectID, groupName, condition, stageName, Dfile, D, stats)

    row = table();
    row.subject_id = string(subjectID);
    row.group = string(groupName);
    row.condition = string(condition);
    row.stage = string(stageName);
    row.Dfile = string(Dfile);
    row.n_channels = nchannels(D);
    row.n_trials = ntrials(D);
    row.n_samples = nsamples(D);
    row.fs = fsample(D);
    row.std_uV = stats.stdVal;
    row.median_abs_uV = stats.medianAbs;
    row.p95_abs_uV = stats.p95Abs;
    row.p99_abs_uV = stats.p99Abs;
    row.max_abs_uV = stats.maxAbs;
end

function [trialMetrics, rejectInfo] = computeTrialFlags(D, cfg)

    eegIdx = getEEGIdx(D);
    nEEG = numel(eegIdx);
    nSamp = nsamples(D);
    nTrial = ntrials(D);

    if cfg.reject_if_fraction_strictly_greater
        nChannelsRequired = floor(cfg.channel_fraction_cutoff * nEEG) + 1;
    else
        nChannelsRequired = ceil(cfg.channel_fraction_cutoff * nEEG);
    end

    p2pN = zeros(nTrial,1);
    p2pFrac = zeros(nTrial,1);
    p2pMax = zeros(nTrial,1);
    p2pP95 = zeros(nTrial,1);

    jumpN = zeros(nTrial,1);
    jumpFrac = zeros(nTrial,1);
    jumpMax = zeros(nTrial,1);
    jumpP95 = zeros(nTrial,1);

    rejectP2P = false(nTrial,1);
    rejectJump = false(nTrial,1);

    for tr = 1:nTrial
        X = double(D(eegIdx, 1:nSamp, tr));

        p2pByChan = max(X,[],2) - min(X,[],2);
        p2pN(tr) = sum(p2pByChan > cfg.p2p_threshold_uV);
        p2pFrac(tr) = p2pN(tr) / nEEG;
        p2pMax(tr) = max(p2pByChan);
        p2pP95(tr) = prctile(p2pByChan, 95);
        rejectP2P(tr) = p2pN(tr) >= nChannelsRequired;

        dX = abs(diff(X,1,2));
        jumpByChan = max(dX,[],2);
        jumpN(tr) = sum(jumpByChan > cfg.jump_threshold_uV);
        jumpFrac(tr) = jumpN(tr) / nEEG;
        jumpMax(tr) = max(jumpByChan);
        jumpP95(tr) = prctile(jumpByChan, 95);

        if cfg.use_jump_guard
            rejectJump(tr) = jumpN(tr) >= nChannelsRequired;
        else
            rejectJump(tr) = false;
        end
    end

    rejectFinal = rejectP2P | rejectJump;

    trialMetrics = struct();
    trialMetrics.p2pNChannelsExceeding = p2pN;
    trialMetrics.p2pFractionChannelsExceeding = p2pFrac;
    trialMetrics.p2pTrialMax = p2pMax;
    trialMetrics.p2pTrialP95Channel = p2pP95;
    trialMetrics.jumpNChannelsExceeding = jumpN;
    trialMetrics.jumpFractionChannelsExceeding = jumpFrac;
    trialMetrics.jumpTrialMax = jumpMax;
    trialMetrics.jumpTrialP95Channel = jumpP95;

    rejectInfo = struct();
    rejectInfo.nEEG = nEEG;
    rejectInfo.nChannelsRequired = nChannelsRequired;
    rejectInfo.rejectP2P = rejectP2P;
    rejectInfo.rejectJump = rejectJump;
    rejectInfo.rejectFinal = rejectFinal;
end

function varName = findVar(T, candidates)

    vars = string(T.Properties.VariableNames);
    normVars = lower(regexprep(vars, '[^a-zA-Z0-9]', ''));

    for i = 1:numel(candidates)
        target = lower(regexprep(string(candidates{i}), '[^a-zA-Z0-9]', ''));
        idx = find(normVars == target, 1);

        if ~isempty(idx)
            varName = vars(idx);
            return;
        end
    end

    error('Could not find variable. Candidates: %s. Available: %s', ...
        strjoin(string(candidates), ', '), strjoin(vars, ', '));
end
