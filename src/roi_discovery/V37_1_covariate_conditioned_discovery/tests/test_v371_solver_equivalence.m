%% Numerical equivalence and timing test for vectorized sparse-group solver.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));addpath(fullfile(root,'tests'));
addpath(fullfile(fileparts(root),'V37_DCM_concordant_ROI_discovery','00_config'));
cfg=v37_config();cfg.optim_max_iterations=120;cfg.optim_tolerance=0;
rng(3711);n=72;ng=48;q=6;X=randn(n,ng*q);Z=randn(n,4);y=double(rand(n,1)>.47);groups=repelem((1:ng)',q);
alphas=[0 .25 .75 1];lambdas=[.002 .02 .2];max_error=0;old_seconds=0;new_seconds=0;
for a=alphas
    for lambda=lambdas
        tic;old=v371_sparse_group_logistic_reference(X,Z,y,groups,lambda,a,cfg);old_seconds=old_seconds+toc;
        tic;new=v371_sparse_group_logistic(X,Z,y,groups,lambda,a,cfg);new_seconds=new_seconds+toc;
        error=max(abs([old.beta-new.beta;old.gamma-new.gamma;old.intercept-new.intercept]));
        max_error=max(max_error,error);assert(old.iterations==new.iterations);assert(error<1e-10);
    end
end
fprintf('V371_SOLVER_EQUIVALENT max_error=%.3g old_s=%.3f new_s=%.3f speedup=%.2fx\n', ...
    max_error,old_seconds,new_seconds,old_seconds/new_seconds);
