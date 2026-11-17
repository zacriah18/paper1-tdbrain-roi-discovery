function node=v35_node_operator(D,cfg,patches,patch_ids)
% DCM-aligned local lead-field modes and inverse-observable node filters.
[~,inverse]=v32_get_inverse(D,cfg.inverse_index);
L=double(inverse.L);M=double(inverse.M);U=inverse.U;
if ~iscell(U),U={U};end
membership=patches.membership;
n=numel(patch_ids);node=struct();node.patch_ids=patch_ids(:);
node.filters=zeros(n,size(U{1},2));node.leadfield=zeros(size(L,1),n);
node.resolution=zeros(size(M,1),n);node.local_basis=cell(n,1);
node.spatial_weights=cell(n,1);node.mode_singular_values=cell(n,1);
for i=1:n
    vv=find(membership(:,patch_ids(i))>0);
    [Q,S,V]=svd(full(L(:,vv)),'econ');k=min([cfg.node_spatial_modes,size(Q,2),size(V,2)]);
    if k<1,error('V35:EmptyPatch','Patch %d has no estimable lead-field mode.',patch_ids(i));end
    regional_modes=V(:,1:k);
    mode_filters=regional_modes'*(M(vv,:)*double(U{1}));
    [A,~,~]=svd(full(mode_filters),'econ');
    w=regional_modes*A(:,1);[~,anchor]=max(abs(w));if w(anchor)<0,w=-w;end
    g=L(:,vv)*w;g=g/(norm(g)+eps);
    node.filters(i,:)=(w'*M(vv,:))*double(U{1});
    node.leadfield(:,i)=g;node.resolution(:,i)=M*g;
    node.local_basis{i}=Q(:,1:k);node.spatial_weights{i}=w;
    sv=diag(S);node.mode_singular_values{i}=sv(1:k);
end
node.inverse=inverse;
end
