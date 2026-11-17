root=fileparts(mfilename('fullpath'));
run(fullfile(root,'07_pre_DCM_gate','A14_run_EO_sensor_ocular_proxy_audit_V371.m'));
run(fullfile(root,'07_pre_DCM_gate','A16_run_validation_CSD_observability_V371.m'));
run(fullfile(root,'07_pre_DCM_gate','A17_finalize_pre_DCM_gate_V371.m'));
