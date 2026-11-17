%% Resumable V37.1 sensor comparator, confined to discovery recordings.
clear;clc;root=fileparts(mfilename('fullpath'));
run(fullfile(root,'04_sensor_comparator','A04_extract_sensor_spectra_V371.m'));
run(fullfile(root,'04_sensor_comparator','A05_assemble_sensor_participant_features_V371.m'));
run(fullfile(root,'04_sensor_comparator','A06_run_sensor_comparator_V371.m'));
fprintf('V37.1 SENSOR COMPARATOR COMPLETE. Validation participants read: 0.\n');
