function H=v371_four_node_hypotheses()
%V371_FOUR_NODE_HYPOTHESES Prespecified nested four-node CSD-DCM family.
% Entry (target,source)=1. CMC A{1}=forward, A{2}=backward, A{3}=lateral.
% Node order: 1 R-occipital, 2 L-auditory/insula,
%             3 R-entorhinal/parahippocampal, 4 R-precuneus/PCC.
n=4;Z=zeros(n);F=Z;B=Z;L=Z;
% Core right posterior-medial hierarchy: occipital -> precuneus -> medial temporal.
F(4,1)=1;B(1,4)=1;F(3,4)=1;B(4,3)=1;
% Cross-hemisphere auditory/insula to association cortex is treated as lateral.
L(4,2)=1;L(2,4)=1;
% Prespecified additions.
shortcutF=Z;shortcutB=Z;shortcutF(3,1)=1;shortcutB(1,3)=1;
limbicL=Z;limbicL(3,2)=1;limbicL(2,3)=1;
crossmodalL=Z;crossmodalL(1,2)=1;crossmodalL(2,1)=1;
H=struct();
H.names=["H1_CORE_POSTERIOR_MEDIAL";"H2_PLUS_OCCIPITAL_MEDIAL_TEMPORAL"; ...
    "H3_PLUS_AUDITORY_LIMBIC";"H4_PARENT_ALL_PLAUSIBLE"];
H.description=["Occipital-precuneus-medial-temporal hierarchy plus reciprocal auditory/insula-precuneus lateral coupling"; ...
    "H1 plus direct occipital-medial-temporal reciprocal pathway"; ...
    "H2 plus reciprocal auditory/insula-medial-temporal lateral pathway"; ...
    "H3 plus reciprocal auditory/insula-occipital cross-modal pathway"];
H.A=cell(4,3);
H.A(1,:)={F,B,L};
H.A(2,:)={F|shortcutF,B|shortcutB,L};
H.A(3,:)={F|shortcutF,B|shortcutB,L|limbicL};
H.A(4,:)={F|shortcutF,B|shortcutB,L|limbicL|crossmodalL};
H.components=struct('core_forward',F,'core_backward',B,'core_lateral',L, ...
    'occipital_medial_temporal_forward',shortcutF, ...
    'occipital_medial_temporal_backward',shortcutB, ...
    'auditory_limbic_lateral',limbicL,'auditory_occipital_lateral',crossmodalL);
end
