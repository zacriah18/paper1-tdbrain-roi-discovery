function contrast = v32_build_contrast(inverse, time_window_ms, frequency_band_hz)
%V32_BUILD_CONTRAST Reproduce SPM's temporal/frequency contrast construction.

T = double(inverse.T);
pst = double(inverse.pst(:));

if isempty(time_window_ms)
    woi = double(inverse.woi(:)');
else
    woi = double(time_window_ms(:)');
end
if numel(woi) ~= 2
    error('V32:InvalidWOI', 'Time window must contain [start end] in ms.');
end
woi(1) = max(woi(1), double(inverse.woi(1)));
woi(2) = min(woi(2), double(inverse.woi(2)));
if woi(2) <= woi(1)
    error('V32:InvalidWOI', 'Requested time window does not overlap inversion window.');
end

fwhm = max(diff(woi), 8);
t = exp(-4*log(2)*(pst - mean(woi)).^2/(fwhm^2));
t = t/sum(t);

foi = double(frequency_band_hz(:)');
if numel(foi) ~= 2 || foi(2) < foi(1)
    error('V32:InvalidFOI', 'Frequency band must contain [low high] Hz.');
end
wt = 2*pi*pst/1000;
W = [];
for f = foi(1):foi(2)
    W = [W sin(f*wt) cos(f*wt)]; %#ok<AGROW>
end
W = diag(t)*W;
W = spm_svd(W, 1);
TW = T'*W;
TTW = T*TW;

qC = double(inverse.qC) * trace(TTW' * double(inverse.qV) * TTW);
qC = max(qC, 0);

contrast = struct();
contrast.woi_ms = woi;
contrast.foi_hz = foi;
contrast.W = W;
contrast.TW = TW;
contrast.TTW = TTW;
contrast.qC = qC;
end
