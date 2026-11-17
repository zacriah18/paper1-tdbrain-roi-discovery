%% Execute the frozen internal held-out confirmation after A08 freeze.
clear;clc;root=fileparts(mfilename('fullpath'));
run(fullfile(root,'06_heldout_validation','A09_extract_validation_node_features_V371.m'));
run(fullfile(root,'06_heldout_validation','A10_assemble_validation_features_V371.m'));
run(fullfile(root,'06_heldout_validation','A11_score_frozen_validation_V371.m'));
