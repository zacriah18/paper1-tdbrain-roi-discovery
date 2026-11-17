function H=v36_connectivity_hypotheses()
% Entry (target,source)=1. CMC A{1}=forward and A{2}=backward.
n=6;Z=zeros(n);coreF=Z;coreB=Z;
% Node order: 1 L-mSFG, 2 R-MFG/IFG, 3 L-ITG/MTG,
%             4 R-AnG/SPL/MOG, 5 L-AnG/MOG, 6 R-ITG/MTG.
coreF(3,5)=1;coreF(6,4)=1;coreF(1,3)=1;coreF(2,6)=1;
coreB(5,3)=1;coreB(4,6)=1;coreB(3,1)=1;coreB(6,2)=1;
dorsalF=Z;dorsalB=Z;dorsalF(1,5)=1;dorsalF(2,4)=1;dorsalB(5,1)=1;dorsalB(4,2)=1;
callosalF=Z;callosalB=Z;
for pair=[1 2;3 6;5 4]'
    i=pair(1);j=pair(2);callosalF(i,j)=1;callosalF(j,i)=1;callosalB(i,j)=1;callosalB(j,i)=1;
end
hubF=Z;hubB=Z;hubF(1,6)=1;hubF(1,4)=1;hubB(6,1)=1;hubB(4,1)=1;
H=struct();H.names=["H1_BILATERAL_SERIAL";"H2_SERIAL_PLUS_DORSAL";"H3_SERIAL_PLUS_CALLOSAL"; ...
    "H4_DORSAL_CALLOSAL";"H5_PARENT_FOCAL_HUB"];
H.description=["Bilateral posterior-to-temporal-to-frontal hierarchy with reciprocal feedback"; ...
    "H1 plus direct within-hemisphere posterior-frontal pathways"; ...
    "H1 plus dual-laminar reciprocal homologous pathways"; ...
    "H1 plus dorsal and homologous pathways"; ...
    "H4 plus contralateral right association inputs to, and feedback from, focal left medial frontal hub"];
H.A=cell(5,3);
H.A(1,:)={coreF,coreB,Z};H.A(2,:)={coreF|dorsalF,coreB|dorsalB,Z};
H.A(3,:)={coreF|callosalF,coreB|callosalB,Z};H.A(4,:)={coreF|dorsalF|callosalF,coreB|dorsalB|callosalB,Z};
H.A(5,:)={coreF|dorsalF|callosalF|hubF,coreB|dorsalB|callosalB|hubB,Z};
H.components=struct('serial_forward',coreF,'serial_backward',coreB,'dorsal_forward',dorsalF, ...
    'dorsal_backward',dorsalB,'callosal_forward',callosalF,'callosal_backward',callosalB, ...
    'focal_hub_forward',hubF,'focal_hub_backward',hubB);
end
