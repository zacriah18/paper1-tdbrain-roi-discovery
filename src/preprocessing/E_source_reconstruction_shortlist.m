%% =========================================================================
% E_source_reconstruction_shortlist_QC.m
%
% Source reconstruction + source-space QC for revised TDBRAIN EEG DCM pipeline.
%
% Purpose
% -------
% This is a refactor of E_source_reconstruction_shortlist.m.
% It keeps the original E-stage responsibilities:
%   1) stage D-cleaned SPM M/EEG files
%   2) attach fiducials
%   3) build canonical template head model
%   4) run SPM M/EEG source inversion
%
% It adds source-QC outputs after inversion:
%   - SPM inversion display PNGs, i.e. the MIP/source-response GUI figure
%   - custom 3D cortical activation scatter views from inverse.J * inverse.T'
%   - per recording source activation metrics
%   - frontal/orbitofrontal dominance proxies for ocular/muscle contamination
%
% Important conceptual note
% -------------------------
% This is still source inversion, not DCM.
% The DCM ROI hypothesis is not used here. This stage estimates a whole-brain
% cortical source activity matrix over the SPM cortical mesh:
%
%   J_full(source, time) = inverse.J{condition} * inverse.T'
%
% DCM later compresses/extracts from this source space into ROI/state dynamics.
%
% Input
% -----
% derivatives/D_artifact_reject_shortlist/D_artifact_reject_shortlist_summary.csv
%
% Expected D fields:
%   final_clean_mat
%   n_trials_good
%   qc_flag
%   status
%
% Output
% ------
% derivatives/E_source_reconstruction_shortlist_QC/
%   E_source_reconstruction_manifest.csv
%   E_source_reconstruction_patch_QA.csv
%   E_source_reconstruction_status.csv
%   E_source_reconstruction_verify.csv
%   E_source_activation_QC_metrics.csv
%   source_QC_images/
%       SPM_MIP/*.png
%       3D_mean/*.png
%       3D_max/*.png
%
% Recommended use
% ---------------
% Run this on the D output from strict artifact rejection. Then inspect:
%   - source_activation_QC_metrics.csv
%   - source_QC_images
% before committing the source-reconstructed files to DCM.
% =========================================================================

clear; clc;

restoredefaultpath;

rootDir = 'C:\MATLAB\2026 TDBRAIN dataset';
spmDir  = 'C:\MATLAB\spm';

addpath(spmDir);
addpath(genpath(fullfile(spmDir, 'config')));
addpath(genpath(fullfile(spmDir, 'matlabbatch')));
addpath(genpath(fullfile(spmDir, 'external', 'fieldtrip')));

spm('defaults','eeg');
spm_jobman('initcfg');
if exist('ft_defaults','file') == 2
    ft_defaults;
end

%% -------------------------------------------------------------------------
% Config
% -------------------------------------------------------------------------

cfg = struct();

% SPM source reconstruction settings.
cfg.useHeadshape = 0;
cfg.meshres = 2;
cfg.val = 1;
cfg.modality = {'EEG'};

% Minimum trial policy for attempting source reconstruction.
% D already labels <20 as review and <10 as error. E skips <10 by default.
cfg.min_good_trials_for_E = 10;
cfg.skip_low_trial_error = true;

% Expected final channel typing after C montage/D rejection.
cfg.expected_EEG_channels = 26;
cfg.expected_EOG_channels = 0;
cfg.expected_Other_channels = 0;

% Source QC controls.
cfg.save_spm_mip_png = true;
cfg.save_custom_3d_png = true;
cfg.close_figures_after_each_subject = true;

% Optional sensitivity overrides. Defaults preserve the original pipeline.
envSaveImages = str2double(getenv('TDBRAIN_E_SAVE_QC_IMAGES'));
if isfinite(envSaveImages)
    cfg.save_spm_mip_png = logical(envSaveImages);
    cfg.save_custom_3d_png = logical(envSaveImages);
end

% How many strongest mesh sources to plot in custom 3D figures.
% Use a small fraction to make the plot interpretable and not a dense cloud.
cfg.plot_top_fraction = 0.02;       % top 2% source points
cfg.plot_min_points = 50;
cfg.plot_max_points = 500;

% Artifact-risk proxy thresholds in MNI-ish coordinates.
% These are not diagnostic labels. They are flags to help inspect likely
% frontal/ocular dominance in source maps.
cfg.frontal_y_mm = 35;              % anterior/frontal
cfg.orbital_y_mm = 35;              % anterior
cfg.orbital_z_mm = 15;              % low/inferior frontal/orbital proxy
cfg.bilateral_x_mm = 15;            % split left/right anterior peaks
cfg.top_k_sources = 20;

% Source dominance flags.
cfg.high_top1_fraction = 0.15;      % one source explains >15% of abs-max mass
cfg.high_top10_fraction = 0.50;     % top 10 explain >50% of abs-max mass

% Output roots. Sensitivity branches must use separate derivative names.
envDOutputName = strtrim(getenv('TDBRAIN_E_D_INPUT_NAME'));
envEOutputName = strtrim(getenv('TDBRAIN_E_OUTPUT_NAME'));
if isempty(envDOutputName), envDOutputName = 'D_artifact_reject_shortlist'; end
if isempty(envEOutputName), envEOutputName = 'E_source_reconstruction_shortlist_QC'; end
namesToCheck = {envDOutputName,envEOutputName};
for nameIndex = 1:numel(namesToCheck)
    value = namesToCheck{nameIndex};
    if contains(value,filesep) || contains(value,'/') || contains(value,'..')
        error('Sensitivity derivative names must be single folder names.');
    end
end
inCSV = fullfile(rootDir, ...
    'derivatives', ...
    envDOutputName, ...
    'D_artifact_reject_shortlist_summary.csv');

outRoot = fullfile(rootDir, ...
    'derivatives', ...
    envEOutputName);

templateElecFile = fullfile(rootDir, 'ZZ_standard_1005.elc');

if ~exist(outRoot, 'dir'), mkdir(outRoot); end

imgRoot = fullfile(outRoot, 'source_QC_images');
imgSpmDir = fullfile(imgRoot, 'SPM_MIP');
img3DMeanDir = fullfile(imgRoot, '3D_mean');
img3DMaxDir = fullfile(imgRoot, '3D_max');
ensureDir(imgRoot);
ensureDir(imgSpmDir);
ensureDir(img3DMeanDir);
ensureDir(img3DMaxDir);

logFile = fullfile(outRoot, 'E_source_reconstruction_shortlist_QC_log.txt');
if exist(logFile, 'file'), delete(logFile); end
diary(logFile);

fprintf('============================================================\n');
fprintf('E SOURCE RECONSTRUCTION + SOURCE QC\n');
fprintf('Input : %s\n', inCSV);
fprintf('Output: %s\n', outRoot);
fprintf('Elec  : %s\n', templateElecFile);
fprintf('Min good trials for E: %d\n', cfg.min_good_trials_for_E);
fprintf('Save SPM MIP PNGs    : %d\n', cfg.save_spm_mip_png);
fprintf('Save custom 3D PNGs  : %d\n', cfg.save_custom_3d_png);
fprintf('============================================================\n');

if ~isfile(inCSV)
    error('Missing D summary file: %s', inCSV);
end

%% -------------------------------------------------------------------------
% Read D summary
% -------------------------------------------------------------------------

T = readtable(inCSV, 'VariableNamingRule', 'preserve');

T.subject_id = string(T.subject_id);
T.group      = string(T.group);
T.condition  = string(T.condition);
T.status     = string(T.status);
T.final_clean_mat = string(T.final_clean_mat);

if any(strcmp(T.Properties.VariableNames, 'qc_flag'))
    T.qc_flag = string(T.qc_flag);
else
    T.qc_flag = repmat("UNKNOWN", height(T), 1);
end

T = T(T.status == "OK" & strlength(T.final_clean_mat) > 0, :);

if cfg.skip_low_trial_error && any(strcmp(T.Properties.VariableNames, 'n_trials_good'))
    beforeN = height(T);
    T = T(T.n_trials_good >= cfg.min_good_trials_for_E, :);
    fprintf('Skipped %d files with fewer than %d good trials.\n', ...
        beforeN - height(T), cfg.min_good_trials_for_E);
end

fprintf('Found %d D-cleaned files for source reconstruction\n', height(T));

% TEST MODE
% T = T(1:4,:);

%% -------------------------------------------------------------------------
% Read template fiducials from ZZ_standard_1005.elc
% -------------------------------------------------------------------------

if ~isfile(templateElecFile)
    error('Missing template electrode file: %s', templateElecFile);
end

elec = ft_read_sens(templateElecFile);
templateLabels = string(elec.label);

nzIdx  = find(strcmpi(templateLabels, 'Nz'), 1);
lpaIdx = find(strcmpi(templateLabels, 'LPA'), 1);
rpaIdx = find(strcmpi(templateLabels, 'RPA'), 1);

if isempty(nzIdx) || isempty(lpaIdx) || isempty(rpaIdx)
    error('Could not find Nz/LPA/RPA fiducials in %s', templateElecFile);
end

fid = [];
fid.fid.label = {'Nz', 'LPA', 'RPA'};
fid.fid.pnt = [
    elec.chanpos(nzIdx,  :)
    elec.chanpos(lpaIdx, :)
    elec.chanpos(rpaIdx, :)
];
fid.unit = 'mm';

fprintf('\nTemplate fiducials from %s:\n', templateElecFile);
disp(fid.fid);

%% -------------------------------------------------------------------------
% Stage files
% -------------------------------------------------------------------------

sourceFiles = strings(0,1);
sourceSubjects = strings(0,1);
sourceGroups = strings(0,1);
sourceConditions = strings(0,1);
sourceGoodTrials = nan(0,1);
sourceQCFlags = strings(0,1);

manifestRows = table();

for i = 1:height(T)

    subjectID = T.subject_id(i);
    groupName = T.group(i);
    condition = T.condition(i);

    srcMat = char(T.final_clean_mat(i));
    srcDat = strrep(srcMat, '.mat', '.dat');

    outDir = fullfile(outRoot, char(groupName), char(condition), char(subjectID));
    ensureDir(outDir);

    [~, base, ext] = fileparts(srcMat);

    dstMat = fullfile(outDir, [base ext]);
    dstDat = fullfile(outDir, [base '.dat']);

    fprintf('\nStaging %03d/%03d | %s | %s | %s\n', ...
        i, height(T), subjectID, groupName, condition);

    if ~isfile(srcMat)
        warning('Missing source .mat file, skipping: %s', srcMat);
        continue;
    end

    copyfile(srcMat, dstMat);

    if exist(srcDat, 'file')
        copyfile(srcDat, dstDat);
    else
        warning('Missing .dat file for %s', srcMat);
    end

    sourceFiles(end+1,1) = string(dstMat); %#ok<SAGROW>
    sourceSubjects(end+1,1) = subjectID; %#ok<SAGROW>
    sourceGroups(end+1,1) = groupName; %#ok<SAGROW>
    sourceConditions(end+1,1) = condition; %#ok<SAGROW>

    if any(strcmp(T.Properties.VariableNames, 'n_trials_good'))
        sourceGoodTrials(end+1,1) = T.n_trials_good(i); %#ok<SAGROW>
    else
        sourceGoodTrials(end+1,1) = NaN; %#ok<SAGROW>
    end

    sourceQCFlags(end+1,1) = T.qc_flag(i); %#ok<SAGROW>

    row = table();
    row.subject_id = subjectID;
    row.group = groupName;
    row.condition = condition;
    row.input_D_clean_file = string(srcMat);
    row.source_ready_file = string(dstMat);
    row.source_ready_dir = string(outDir);

    if any(strcmp(T.Properties.VariableNames, 'n_trials_before'))
        row.n_trials_before_D = T.n_trials_before(i);
    else
        row.n_trials_before_D = NaN;
    end

    if any(strcmp(T.Properties.VariableNames, 'n_trials_good'))
        row.n_trials_good_D = T.n_trials_good(i);
    else
        row.n_trials_good_D = NaN;
    end

    if any(strcmp(T.Properties.VariableNames, 'rejection_fraction'))
        row.D_rejection_fraction = T.rejection_fraction(i);
    else
        row.D_rejection_fraction = NaN;
    end

    row.D_qc_flag = T.qc_flag(i);

    manifestRows = [manifestRows; row]; %#ok<AGROW>
end

%% -------------------------------------------------------------------------
% Patch fiducials and metadata QA
% -------------------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf('PATCHING FIDUCIALS + VERIFYING CHANNELS\n');
fprintf('============================================================\n');

patchRows = table();

for i = 1:numel(sourceFiles)

    status = "OK";
    errMsg = "";

    fprintf('Patching fiducials %03d/%03d: %s\n', ...
        i, numel(sourceFiles), sourceFiles(i));

    try
        D = spm_eeg_load(char(sourceFiles(i)));

        verifyPostDChannelTypes(D, cfg);

        % Do not rescale. Just assert/report units and attach fiducials.
        D = fiducials(D, fid);

        save(D);

        rowStats = quickStatsEEG(D);

        row = table();
        row.subject_id = sourceSubjects(i);
        row.group = sourceGroups(i);
        row.condition = sourceConditions(i);
        row.source_file = sourceFiles(i);
        row.n_channels = nchannels(D);
        row.n_trials = ntrials(D);
        row.n_samples = nsamples(D);
        row.fs = fsample(D);
        row.std_uV = rowStats.stdVal;
        row.p95_abs_uV = rowStats.p95Abs;
        row.max_abs_uV = rowStats.maxAbs;
        row.status = status;
        row.error_message = errMsg;

    catch ME
        status = "FAILED";
        errMsg = string(ME.message);

        fprintf('ERROR patching fiducials/channel QA:\n%s\n', ME.message);

        row = table();
        row.subject_id = sourceSubjects(i);
        row.group = sourceGroups(i);
        row.condition = sourceConditions(i);
        row.source_file = sourceFiles(i);
        row.n_channels = NaN;
        row.n_trials = NaN;
        row.n_samples = NaN;
        row.fs = NaN;
        row.std_uV = NaN;
        row.p95_abs_uV = NaN;
        row.max_abs_uV = NaN;
        row.status = status;
        row.error_message = errMsg;
    end

    patchRows = [patchRows; row]; %#ok<AGROW>
end

%% -------------------------------------------------------------------------
% Source reconstruction + source QC extraction
% -------------------------------------------------------------------------

statusRows = table();
activationRows = table();

for i = 1:numel(sourceFiles)

    Dfile = char(sourceFiles(i));
    subjectID = sourceSubjects(i);
    groupName = sourceGroups(i);
    condition = sourceConditions(i);

    fprintf('\n============================================================\n');
    fprintf('Source reconstruction %03d/%03d\n', i, numel(sourceFiles));
    fprintf('Subject:   %s\n', subjectID);
    fprintf('Group:     %s\n', groupName);
    fprintf('Condition: %s\n', condition);
    fprintf('Good trials from D: %.0f\n', sourceGoodTrials(i));
    fprintf('D QC flag:  %s\n', sourceQCFlags(i));
    fprintf('File:      %s\n', Dfile);
    fprintf('============================================================\n');

    status = "OK";
    errMsg = "";
    sourceQCStatus = "NOT_RUN";
    sourceQCError = "";

    try
        clear matlabbatch;

        %% 1. Head model
        matlabbatch{1}.spm.meeg.source.headmodel.D = {Dfile};
        matlabbatch{1}.spm.meeg.source.headmodel.val = cfg.val;
        matlabbatch{1}.spm.meeg.source.headmodel.comment = '';

        matlabbatch{1}.spm.meeg.source.headmodel.meshing.meshes.template = 1;
        matlabbatch{1}.spm.meeg.source.headmodel.meshing.meshres = cfg.meshres;

        matlabbatch{1}.spm.meeg.source.headmodel.coregistration.coregspecify.fiducial(1).fidname = 'Nz';
        matlabbatch{1}.spm.meeg.source.headmodel.coregistration.coregspecify.fiducial(1).specification.select = 'nas';

        matlabbatch{1}.spm.meeg.source.headmodel.coregistration.coregspecify.fiducial(2).fidname = 'LPA';
        matlabbatch{1}.spm.meeg.source.headmodel.coregistration.coregspecify.fiducial(2).specification.select = 'lpa';

        matlabbatch{1}.spm.meeg.source.headmodel.coregistration.coregspecify.fiducial(3).fidname = 'RPA';
        matlabbatch{1}.spm.meeg.source.headmodel.coregistration.coregspecify.fiducial(3).specification.select = 'rpa';

        matlabbatch{1}.spm.meeg.source.headmodel.coregistration.coregspecify.useheadshape = cfg.useHeadshape;

        matlabbatch{1}.spm.meeg.source.headmodel.forward.eeg = 'EEG BEM';
        matlabbatch{1}.spm.meeg.source.headmodel.forward.meg = 'Single Shell';

        %% 2. Source inversion
        matlabbatch{2}.spm.meeg.source.invert.D = {Dfile};
        matlabbatch{2}.spm.meeg.source.invert.val = cfg.val;
        matlabbatch{2}.spm.meeg.source.invert.whatconditions.all = 1;
        matlabbatch{2}.spm.meeg.source.invert.isstandard.standard = 1;
        matlabbatch{2}.spm.meeg.source.invert.modality = cfg.modality;

        spm_jobman('run', matlabbatch);

        fprintf('SUCCESS source reconstruction: %s %s\n', subjectID, condition);

        %% 3. Source-QC metrics and figures
        try
            [qcRow, qcFiles] = extractAndSaveSourceQC(Dfile, cfg, ...
                subjectID, groupName, condition, sourceGoodTrials(i), sourceQCFlags(i), ...
                imgSpmDir, img3DMeanDir, img3DMaxDir);

            qcRow.source_QC_status = "OK";
            qcRow.source_QC_error = "";
            activationRows = [activationRows; qcRow]; %#ok<AGROW>

            sourceQCStatus = "OK";
            fprintf('Source QC saved: SPM=%s | 3Dmean=%s | 3Dmax=%s\n', ...
                qcFiles.spm_png, qcFiles.mean3d_png, qcFiles.max3d_png);

        catch MEqc
            sourceQCStatus = "FAILED";
            sourceQCError = string(MEqc.message);
            fprintf('WARNING source QC extraction failed: %s\n', MEqc.message);

            qcRow = makeEmptyQCRow(Dfile, cfg, subjectID, groupName, condition, ...
                sourceGoodTrials(i), sourceQCFlags(i), sourceQCStatus, sourceQCError);
            activationRows = [activationRows; qcRow]; %#ok<AGROW>
        end

    catch ME

        status = "FAILED";
        errMsg = string(ME.message);

        fprintf('\nERROR source reconstruction failed:\n');
        fprintf('Subject:   %s\n', subjectID);
        fprintf('Condition: %s\n', condition);
        fprintf('%s\n', Dfile);
        fprintf('%s\n', ME.message);

        for e = 1:numel(ME.stack)
            fprintf(' -> %s line %d\n', ME.stack(e).name, ME.stack(e).line);
        end

        qcRow = makeEmptyQCRow(Dfile, cfg, subjectID, groupName, condition, ...
            sourceGoodTrials(i), sourceQCFlags(i), "NOT_RUN_SOURCE_FAILED", errMsg);
        activationRows = [activationRows; qcRow]; %#ok<AGROW>
    end

    row = table();
    row.subject_id = subjectID;
    row.group = groupName;
    row.condition = condition;
    row.source_file = string(Dfile);
    row.n_trials_good_D = sourceGoodTrials(i);
    row.D_qc_flag = sourceQCFlags(i);
    row.status = status;
    row.error_message = errMsg;
    row.source_QC_status = sourceQCStatus;
    row.source_QC_error = sourceQCError;

    statusRows = [statusRows; row]; %#ok<AGROW>
end

%% -------------------------------------------------------------------------
% Verify outputs
% -------------------------------------------------------------------------

verifyRows = table();

fprintf('\n============================================================\n');
fprintf('VERIFYING SOURCE RECONSTRUCTION OUTPUTS\n');
fprintf('============================================================\n');

for i = 1:numel(sourceFiles)

    Dfile = char(sourceFiles(i));

    hasInv = false;
    nInv = 0;
    hasForward = false;
    hasDataReg = false;
    hasInverse = false;
    hasJ = false;
    hasT = false;
    hasR2 = false;
    hasF = false;
    verifyStatus = "OK";
    verifyError = "";

    try
        Dcheck = spm_eeg_load(Dfile);
        Draw = struct(Dcheck);

        if isfield(Draw, 'other') && ...
           isfield(Draw.other, 'inv') && ...
           ~isempty(Draw.other.inv)

            hasInv = true;
            nInv = numel(Draw.other.inv);

            try
                inv1 = Draw.other.inv{cfg.val};
                hasForward = isfield(inv1, 'forward') && ~isempty(inv1.forward);
                hasDataReg = isfield(inv1, 'datareg') && ~isempty(inv1.datareg);
                hasInverse = isfield(inv1, 'inverse') && ~isempty(inv1.inverse);
                if hasInverse
                    hasJ = isfield(inv1.inverse, 'J') && ~isempty(inv1.inverse.J);
                    hasT = isfield(inv1.inverse, 'T') && ~isempty(inv1.inverse.T);
                    hasR2 = isfield(inv1.inverse, 'R2');
                    hasF = isfield(inv1.inverse, 'F');
                end
            catch
                hasForward = false;
                hasDataReg = false;
            end
        end

    catch ME
        verifyStatus = "FAILED";
        verifyError = string(ME.message);
    end

    fprintf('%s | %s | inv=%d | nInv=%d | forward=%d | datareg=%d | inverse=%d | J=%d | T=%d\n', ...
        sourceSubjects(i), sourceConditions(i), hasInv, nInv, hasForward, hasDataReg, hasInverse, hasJ, hasT);

    row = table();
    row.subject_id = sourceSubjects(i);
    row.group = sourceGroups(i);
    row.condition = sourceConditions(i);
    row.source_file = sourceFiles(i);
    row.n_trials_good_D = sourceGoodTrials(i);
    row.D_qc_flag = sourceQCFlags(i);
    row.has_D_other_inv = hasInv;
    row.n_inv = nInv;
    row.has_forward = hasForward;
    row.has_datareg = hasDataReg;
    row.has_inverse = hasInverse;
    row.has_inverse_J = hasJ;
    row.has_inverse_T = hasT;
    row.has_inverse_R2 = hasR2;
    row.has_inverse_F = hasF;
    row.verify_status = verifyStatus;
    row.verify_error = verifyError;

    verifyRows = [verifyRows; row]; %#ok<AGROW>
end

%% -------------------------------------------------------------------------
% Save manifests
% -------------------------------------------------------------------------

manifestFile   = fullfile(outRoot, 'E_source_reconstruction_manifest.csv');
patchFile      = fullfile(outRoot, 'E_source_reconstruction_patch_QA.csv');
statusFile     = fullfile(outRoot, 'E_source_reconstruction_status.csv');
verifyFile     = fullfile(outRoot, 'E_source_reconstruction_verify.csv');
activationFile = fullfile(outRoot, 'E_source_activation_QC_metrics.csv');

writetable(manifestRows, manifestFile);
writetable(patchRows, patchFile);
writetable(statusRows, statusFile);
writetable(verifyRows, verifyFile);
writetable(activationRows, activationFile);

fprintf('\n============================================================\n');
fprintf('E source reconstruction + QC complete.\n');
fprintf('Manifest     : %s\n', manifestFile);
fprintf('Patch QA     : %s\n', patchFile);
fprintf('Status       : %s\n', statusFile);
fprintf('Verify       : %s\n', verifyFile);
fprintf('Activation QC: %s\n', activationFile);
fprintf('Image root   : %s\n', imgRoot);
fprintf('Output root  : %s\n', outRoot);

fprintf('\nStatus counts:\n');
if ~isempty(statusRows)
    disp(groupsummary(statusRows, 'status'));
end

fprintf('\nSource QC status counts:\n');
if ~isempty(activationRows) && any(strcmp(activationRows.Properties.VariableNames, 'source_QC_status'))
    disp(groupsummary(activationRows, 'source_QC_status'));
end

fprintf('============================================================\n');

diary off;

%% =========================================================================
% Helpers
% =========================================================================

function ensureDir(p)
    if ~exist(p, 'dir')
        mkdir(p);
    end
end

function verifyPostDChannelTypes(D, cfg)

    types = string(D.chantype);
    types = types(:);

    nEEG = sum(strcmpi(types, 'EEG'));
    nEOG = sum(strcmpi(types, 'EOG'));
    nOther = sum(strcmpi(types, 'Other'));

    fprintf('CHANNEL QA | EEG=%d EOG=%d Other=%d\n', nEEG, nEOG, nOther);

    if nEEG ~= cfg.expected_EEG_channels
        error('Expected %d EEG channels after D, found %d.', ...
            cfg.expected_EEG_channels, nEEG);
    end

    if nEOG ~= cfg.expected_EOG_channels
        error('Expected %d EOG channels after D, found %d.', ...
            cfg.expected_EOG_channels, nEOG);
    end

    if nOther ~= cfg.expected_Other_channels
        error('Expected %d Other channels after D, found %d.', ...
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

function [qcRow, qcFiles] = extractAndSaveSourceQC(Dfile, cfg, subjectID, groupName, condition, nGoodTrials, dQCFlag, imgSpmDir, img3DMeanDir, img3DMaxDir)

    Dpost = spm_eeg_load(Dfile);
    invModel = getInvModel(Dpost, cfg.val);
    inverse = invModel.inverse;

    [Jfull, pstMs, conIndex] = reconstructFullJ(inverse);
    [coords, coordStatus] = getSourceCoordinates(invModel, size(Jfull,1));

    sourceMeanAbs = mean(abs(Jfull), 2, 'omitnan');
    sourceMaxAbs = max(abs(Jfull), [], 2, 'omitnan');
    sourceRMS = sqrt(mean(Jfull.^2, 2, 'omitnan'));

    [peakMaxAbs, peakIndex] = max(sourceMaxAbs);
    [~, peakTimeIndex] = max(abs(Jfull(peakIndex,:)));

    if ~isempty(pstMs) && numel(pstMs) >= peakTimeIndex
        peakTimeMs = pstMs(peakTimeIndex);
    else
        peakTimeMs = NaN;
    end

    if ~isempty(coords) && size(coords,1) >= peakIndex
        peakXYZ = coords(peakIndex,:);
    else
        peakXYZ = [NaN NaN NaN];
    end

    absMass = sum(sourceMaxAbs, 'omitnan');
    if absMass <= 0 || ~isfinite(absMass)
        top1Frac = NaN;
        top10Frac = NaN;
        frontalMassFrac = NaN;
        orbitalMassFrac = NaN;
        leftFrontalMassFrac = NaN;
        rightFrontalMassFrac = NaN;
    else
        sortedVals = sort(sourceMaxAbs, 'descend');
        top1Frac = sortedVals(1) / absMass;
        top10Frac = sum(sortedVals(1:min(10,numel(sortedVals))), 'omitnan') / absMass;

        if ~isempty(coords)
            frontalMask = coords(:,2) >= cfg.frontal_y_mm;
            orbitalMask = coords(:,2) >= cfg.orbital_y_mm & coords(:,3) <= cfg.orbital_z_mm;
            leftFrontalMask = frontalMask & coords(:,1) <= -cfg.bilateral_x_mm;
            rightFrontalMask = frontalMask & coords(:,1) >= cfg.bilateral_x_mm;

            frontalMassFrac = sum(sourceMaxAbs(frontalMask), 'omitnan') / absMass;
            orbitalMassFrac = sum(sourceMaxAbs(orbitalMask), 'omitnan') / absMass;
            leftFrontalMassFrac = sum(sourceMaxAbs(leftFrontalMask), 'omitnan') / absMass;
            rightFrontalMassFrac = sum(sourceMaxAbs(rightFrontalMask), 'omitnan') / absMass;
        else
            frontalMassFrac = NaN;
            orbitalMassFrac = NaN;
            leftFrontalMassFrac = NaN;
            rightFrontalMassFrac = NaN;
        end
    end

    if ~isempty(coords)
        [~, orderIdx] = sort(sourceMaxAbs, 'descend');
        topK = orderIdx(1:min(cfg.top_k_sources, numel(orderIdx)));
        topCoords = coords(topK,:);
        topInFrontal = topCoords(:,2) >= cfg.frontal_y_mm;
        topInOrbital = topCoords(:,2) >= cfg.orbital_y_mm & topCoords(:,3) <= cfg.orbital_z_mm;
        topLeftFrontal = topInFrontal & topCoords(:,1) <= -cfg.bilateral_x_mm;
        topRightFrontal = topInFrontal & topCoords(:,1) >= cfg.bilateral_x_mm;

        nTopFrontal = sum(topInFrontal);
        nTopOrbital = sum(topInOrbital);
        nTopLeftFrontal = sum(topLeftFrontal);
        nTopRightFrontal = sum(topRightFrontal);
        bilateralFrontalTopFlag = nTopLeftFrontal > 0 && nTopRightFrontal > 0;
    else
        nTopFrontal = NaN;
        nTopOrbital = NaN;
        nTopLeftFrontal = NaN;
        nTopRightFrontal = NaN;
        bilateralFrontalTopFlag = false;
    end

    likelyFrontalDominance = false;
    likelyOrbitalDominance = false;
    highSourceConcentration = false;

    if all(isfinite(peakXYZ))
        likelyFrontalDominance = peakXYZ(2) >= cfg.frontal_y_mm;
        likelyOrbitalDominance = peakXYZ(2) >= cfg.orbital_y_mm && peakXYZ(3) <= cfg.orbital_z_mm;
    end

    if isfinite(top1Frac) && isfinite(top10Frac)
        highSourceConcentration = top1Frac >= cfg.high_top1_fraction || top10Frac >= cfg.high_top10_fraction;
    end

    % Save SPM inversion/MIP display.
    safeBase = makeSafeBase(subjectID, groupName, condition);
    qcFiles = struct();
    qcFiles.spm_png = "";
    qcFiles.mean3d_png = "";
    qcFiles.max3d_png = "";

    if cfg.save_spm_mip_png
        qcFiles.spm_png = string(fullfile(imgSpmDir, [safeBase '_SPM_MIP.png']));
        saveSpmInvertDisplayPng(Dpost, char(qcFiles.spm_png), cfg);
    end

    % Save custom 3D views from J summary on source coordinates.
    if cfg.save_custom_3d_png && ~isempty(coords)
        qcFiles.mean3d_png = string(fullfile(img3DMeanDir, [safeBase '_3D_meanAbs.png']));
        qcFiles.max3d_png  = string(fullfile(img3DMaxDir,  [safeBase '_3D_maxAbs.png']));

        saveSource3DScatter(coords, sourceMeanAbs, char(qcFiles.mean3d_png), ...
            sprintf('%s %s %s | mean abs source activity', groupName, condition, subjectID), cfg);
        saveSource3DScatter(coords, sourceMaxAbs, char(qcFiles.max3d_png), ...
            sprintf('%s %s %s | max abs source activity', groupName, condition, subjectID), cfg);
    end

    qcRow = table();
    qcRow.subject_id = string(subjectID);
    qcRow.group = string(groupName);
    qcRow.condition = string(condition);
    qcRow.source_file = string(Dfile);
    qcRow.n_trials_good_D = nGoodTrials;
    qcRow.D_qc_flag = string(dQCFlag);
    qcRow.inv_condition_index = conIndex;
    qcRow.n_sources = size(Jfull,1);
    qcRow.n_timepoints = size(Jfull,2);
    qcRow.coord_status = string(coordStatus);
    qcRow.inverse_R2 = safeGetNumeric(inverse, 'R2');
    qcRow.inverse_F = safeGetNumeric(inverse, 'F');
    qcRow.peak_source_index = peakIndex;
    qcRow.peak_time_index = peakTimeIndex;
    qcRow.peak_time_ms = peakTimeMs;
    qcRow.peak_abs_value = peakMaxAbs;
    qcRow.peak_x = peakXYZ(1);
    qcRow.peak_y = peakXYZ(2);
    qcRow.peak_z = peakXYZ(3);
    qcRow.global_mean_abs_source = mean(sourceMeanAbs, 'omitnan');
    qcRow.global_median_abs_source = median(sourceMeanAbs, 'omitnan');
    qcRow.global_p95_abs_source = prctile(sourceMeanAbs, 95);
    qcRow.global_max_abs_source = max(sourceMaxAbs, [], 'omitnan');
    qcRow.source_top1_mass_fraction = top1Frac;
    qcRow.source_top10_mass_fraction = top10Frac;
    qcRow.frontal_mass_fraction = frontalMassFrac;
    qcRow.orbital_mass_fraction = orbitalMassFrac;
    qcRow.left_frontal_mass_fraction = leftFrontalMassFrac;
    qcRow.right_frontal_mass_fraction = rightFrontalMassFrac;
    qcRow.n_top_sources_frontal = nTopFrontal;
    qcRow.n_top_sources_orbital = nTopOrbital;
    qcRow.n_top_sources_left_frontal = nTopLeftFrontal;
    qcRow.n_top_sources_right_frontal = nTopRightFrontal;
    qcRow.flag_peak_frontal = likelyFrontalDominance;
    qcRow.flag_peak_orbital = likelyOrbitalDominance;
    qcRow.flag_bilateral_frontal_top_sources = bilateralFrontalTopFlag;
    qcRow.flag_high_source_concentration = highSourceConcentration;
    qcRow.spm_mip_png = string(qcFiles.spm_png);
    qcRow.source_3d_mean_png = string(qcFiles.mean3d_png);
    qcRow.source_3d_max_png = string(qcFiles.max3d_png);
end

function invModel = getInvModel(D, val)
    Draw = struct(D);
    if ~isfield(Draw, 'other') || ~isfield(Draw.other, 'inv') || isempty(Draw.other.inv)
        error('No D.other.inv found after source inversion.');
    end
    if numel(Draw.other.inv) < val || isempty(Draw.other.inv{val})
        error('D.other.inv{%d} is missing or empty.', val);
    end
    invModel = Draw.other.inv{val};
    if ~isfield(invModel, 'inverse') || isempty(invModel.inverse)
        error('D.other.inv{%d}.inverse is missing.', val);
    end
end

function [Jfull, pstMs, conIndex] = reconstructFullJ(inverse)
    if ~isfield(inverse, 'J') || isempty(inverse.J)
        error('inverse.J is missing.');
    end
    if ~isfield(inverse, 'T') || isempty(inverse.T)
        error('inverse.T is missing.');
    end

    if iscell(inverse.J)
        conIndex = 1;
        Jbase = inverse.J{conIndex};
    else
        conIndex = 1;
        Jbase = inverse.J;
    end

    T = inverse.T;
    Jfull = double(Jbase) * double(T)';

    if isfield(inverse, 'pst') && ~isempty(inverse.pst)
        pstMs = double(inverse.pst(:));
    else
        pstMs = [];
    end
end

function [coords, coordStatus] = getSourceCoordinates(invModel, nSources)
    coords = [];
    coordStatus = "NOT_FOUND";

    % Prefer MNI/template mesh vertices if available.
    candidateFields = {};

    if isfield(invModel, 'mesh')
        candidateFields{end+1} = {'mesh','tess_mni','vert'}; %#ok<AGROW>
        candidateFields{end+1} = {'mesh','tess_ctx','vert'}; %#ok<AGROW>
        candidateFields{end+1} = {'mesh','tess_scalp','vert'}; %#ok<AGROW>
    end

    if isfield(invModel, 'forward')
        candidateFields{end+1} = {'forward','mesh','vert'}; %#ok<AGROW>
        candidateFields{end+1} = {'forward','vert'}; %#ok<AGROW>
    end

    for c = 1:numel(candidateFields)
        try
            val = getNestedField(invModel, candidateFields{c});
            if isnumeric(val) && size(val,2) == 3 && size(val,1) >= nSources
                coords = double(val(1:nSources,:));
                coordStatus = strjoin(string(candidateFields{c}), '.');
                return;
            end
        catch
        end
    end

    % Some SPM structures store source positions as dipfit or Grid fields.
    if isfield(invModel, 'inverse') && isfield(invModel.inverse, 'xyz')
        xyz = invModel.inverse.xyz;
        if isnumeric(xyz) && size(xyz,1) == 3 && size(xyz,2) >= nSources
            coords = double(xyz(:,1:nSources))';
            coordStatus = "inverse.xyz_transposed";
            return;
        elseif isnumeric(xyz) && size(xyz,2) == 3 && size(xyz,1) >= nSources
            coords = double(xyz(1:nSources,:));
            coordStatus = "inverse.xyz";
            return;
        end
    end
end

function val = getNestedField(S, pathParts)
    val = S;
    for k = 1:numel(pathParts)
        val = val.(pathParts{k});
    end
end

function x = safeGetNumeric(S, fieldName)
    if isfield(S, fieldName)
        raw = S.(fieldName);
        if isnumeric(raw) && ~isempty(raw)
            x = double(raw(1));
        else
            x = NaN;
        end
    else
        x = NaN;
    end
end

function safeBase = makeSafeBase(subjectID, groupName, condition)
    safeBase = sprintf('%s_%s_%s', char(groupName), char(condition), char(subjectID));
    safeBase = regexprep(safeBase, '[^a-zA-Z0-9_\-]', '_');
end

function saveSpmInvertDisplayPng(Dpost, outPng, cfg)
    if cfg.close_figures_after_each_subject
        close all force;
    end

    % spm_eeg_invert_display is the GUI/MIP source-response display.
    spm_eeg_invert_display(Dpost);
    drawnow;

    figs = findall(0, 'Type', 'figure');
    if isempty(figs)
        error('spm_eeg_invert_display did not create a figure.');
    end

    % Save the newest/highest-numbered figure. Usually the SPM Graphics window.
    fig = figs(1);
    try
        set(fig, 'Color', 'w');
    catch
    end

    try
        exportgraphics(fig, outPng, 'Resolution', 200);
    catch
        print(fig, outPng, '-dpng', '-r200');
    end

    if cfg.close_figures_after_each_subject
        close all force;
    end
end

function saveSource3DScatter(coords, values, outPng, ttl, cfg)
    values = double(values(:));
    coords = double(coords);

    finiteMask = all(isfinite(coords),2) & isfinite(values);
    coords = coords(finiteMask,:);
    values = values(finiteMask);

    if isempty(values)
        error('No finite coordinates/values available for custom 3D source figure.');
    end

    n = numel(values);
    nPlot = max(cfg.plot_min_points, round(cfg.plot_top_fraction * n));
    nPlot = min([nPlot, cfg.plot_max_points, n]);

    [~, ord] = sort(values, 'descend');
    keep = ord(1:nPlot);

    x = coords(keep,1);
    y = coords(keep,2);
    z = coords(keep,3);
    v = values(keep);

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 400]);

    tiledlayout(1,3, 'Padding', 'compact', 'TileSpacing', 'compact');

    nexttile;
    scatter3(x,y,z,24,v,'filled');
    title('Axial-like');
    xlabel('X'); ylabel('Y'); zlabel('Z');
    axis equal tight; grid on; view(0,90); colorbar;

    nexttile;
    scatter3(x,y,z,24,v,'filled');
    title('Coronal-like');
    xlabel('X'); ylabel('Y'); zlabel('Z');
    axis equal tight; grid on; view(0,0); colorbar;

    nexttile;
    scatter3(x,y,z,24,v,'filled');
    title('Sagittal-like');
    xlabel('X'); ylabel('Y'); zlabel('Z');
    axis equal tight; grid on; view(90,0); colorbar;

    sgtitle(ttl, 'Interpreter', 'none');

    try
        exportgraphics(fig, outPng, 'Resolution', 200);
    catch
        print(fig, outPng, '-dpng', '-r200');
    end

    close(fig);
end

function qcRow = makeEmptyQCRow(Dfile, cfg, subjectID, groupName, condition, nGoodTrials, dQCFlag, qcStatus, qcError)
    qcRow = table();
    qcRow.subject_id = string(subjectID);
    qcRow.group = string(groupName);
    qcRow.condition = string(condition);
    qcRow.source_file = string(Dfile);
    qcRow.n_trials_good_D = nGoodTrials;
    qcRow.D_qc_flag = string(dQCFlag);
    qcRow.inv_condition_index = NaN;
    qcRow.n_sources = NaN;
    qcRow.n_timepoints = NaN;
    qcRow.coord_status = "";
    qcRow.inverse_R2 = NaN;
    qcRow.inverse_F = NaN;
    qcRow.peak_source_index = NaN;
    qcRow.peak_time_index = NaN;
    qcRow.peak_time_ms = NaN;
    qcRow.peak_abs_value = NaN;
    qcRow.peak_x = NaN;
    qcRow.peak_y = NaN;
    qcRow.peak_z = NaN;
    qcRow.global_mean_abs_source = NaN;
    qcRow.global_median_abs_source = NaN;
    qcRow.global_p95_abs_source = NaN;
    qcRow.global_max_abs_source = NaN;
    qcRow.source_top1_mass_fraction = NaN;
    qcRow.source_top10_mass_fraction = NaN;
    qcRow.frontal_mass_fraction = NaN;
    qcRow.orbital_mass_fraction = NaN;
    qcRow.left_frontal_mass_fraction = NaN;
    qcRow.right_frontal_mass_fraction = NaN;
    qcRow.n_top_sources_frontal = NaN;
    qcRow.n_top_sources_orbital = NaN;
    qcRow.n_top_sources_left_frontal = NaN;
    qcRow.n_top_sources_right_frontal = NaN;
    qcRow.flag_peak_frontal = false;
    qcRow.flag_peak_orbital = false;
    qcRow.flag_bilateral_frontal_top_sources = false;
    qcRow.flag_high_source_concentration = false;
    qcRow.spm_mip_png = "";
    qcRow.source_3d_mean_png = "";
    qcRow.source_3d_max_png = "";
    qcRow.source_QC_status = string(qcStatus);
    qcRow.source_QC_error = string(qcError);
end
