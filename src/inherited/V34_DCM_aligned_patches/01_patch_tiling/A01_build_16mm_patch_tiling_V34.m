%% Tile the cortical mesh with connected overlapping 16-mm geodesic patches.
clear;clc;root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'lib'));cfg=v34_setup();
out=fullfile(cfg.output_root,'01_patch_tiling');if ~exist(out,'dir'),mkdir(out);end
F=load(fullfile(cfg.project_root,'derivatives','V32_induced','07_resolution_supports', ...
    'A07_frozen_resolution_supports_LOCKED.mat'),'frozen');f=F.frozen;
A=load(fullfile(cfg.project_root,'derivatives','V32_induced','06_atlas_scaffold', ...
    'A06_atlas_mesh_scaffold.mat'),'atlas_scaffold');atlas=A.atlas_scaffold;
vertices=double(f.vertices);faces=double(f.faces);cortical=f.support_id>0;hemi=string(atlas.hemisphere);
edges=[faces(:,[1 2]);faces(:,[2 3]);faces(:,[3 1])];edges=unique(sort(edges,2),'rows');
w=sqrt(sum((vertices(edges(:,1),:)-vertices(edges(:,2),:)).^2,2));g=graph(edges(:,1),edges(:,2),w,size(vertices,1));
centres=[];
for h=["left","right"]
    target=find(cortical&hemi==h);centroid=mean(vertices(target,:),1);[~,q]=max(sum((vertices(target,:)-centroid).^2,2));
    local_centres=target(q);minimum=distances(g,local_centres(1))';minimum(~(cortical&hemi==h))=-Inf;
    while max(minimum)>cfg.patch_radius_mm
        [~,next]=max(minimum);local_centres(end+1)=next; %#ok<AGROW>
        d=distances(g,next)';valid=cortical&hemi==h;minimum(valid)=min(minimum(valid),d(valid));
    end
    centres=[centres local_centres]; %#ok<AGROW>
end
npatch=numel(centres);membership=sparse(numel(cortical),npatch);patch_table=table();
for p=1:npatch
    d=distances(g,centres(p))';members=find(d<=cfg.patch_radius_mm&cortical&hemi==hemi(centres(p)));
    membership(members,p)=1;
    names=string(atlas.atlas_name(members));u=unique(names);counts=arrayfun(@(x)sum(names==x),u);[counts,o]=sort(counts,'descend');u=u(o);
    overlap=strjoin(u+"="+compose('%.3f',counts/numel(members)),'; ');
    r=table(p,centres(p),hemi(centres(p)),vertices(centres(p),1),vertices(centres(p),2), ...
        vertices(centres(p),3),numel(members),max(d(members)),overlap, ...
        'VariableNames',{'patch_id','centre_vertex','hemisphere','x','y','z', ...
        'n_vertices','max_geodesic_radius_mm','atlas_overlap'});patch_table=[patch_table;r]; %#ok<AGROW>
end
coverage=full(sum(membership,2));if any(coverage(cortical)==0),error('Patch tiling left cortical vertices uncovered.');end
patches=struct('vertices',vertices,'faces',faces,'cortical_mask',cortical,'hemisphere',hemi, ...
    'centres',centres(:),'membership',membership,'patch_table',patch_table,'radius_mm',cfg.patch_radius_mm);
save(fullfile(out,'A01_DCM_aligned_16mm_patches.mat'),'patches','cfg','-v7.3');
writetable(patch_table,fullfile(out,'A01_DCM_aligned_16mm_patch_centres.csv'));
fprintf('Built %d overlapping 16-mm patches; cortical overlap median %.1f patches/vertex.\n',npatch,median(coverage(cortical)));
