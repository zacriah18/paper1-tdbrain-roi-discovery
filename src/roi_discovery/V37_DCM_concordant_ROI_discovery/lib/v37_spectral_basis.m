function B = v37_spectral_basis(nfrequency, nbasis)
%V37_SPECTRAL_BASIS Fixed orthonormal cosine basis; no cohort fitting.
x = (0:nfrequency-1)';
B = zeros(nfrequency, nbasis);
B(:,1) = 1/sqrt(nfrequency);
for k = 2:nbasis
    B(:,k) = sqrt(2/nfrequency) * ...
        cos(pi * (2*x + 1) * (k-1) / (2*nfrequency));
end
end
