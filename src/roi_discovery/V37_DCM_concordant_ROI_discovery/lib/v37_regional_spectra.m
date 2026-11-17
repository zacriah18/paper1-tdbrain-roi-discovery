function spectral = v37_regional_spectra(D, cfg, region)
%V37_REGIONAL_SPECTRA Fast full-curve screen over exact six-mode IMG regions.
%
% SPM CSD-DCM uses VAR(8) spectra at sensor level. Whole-brain source
% screening instead uses a fixed two-second Hann-window spectrum for speed.
% It targets the same 4--45 Hz phenomenon; shortlisted nodes receive the
% later SPM-style VAR and directed-dependence audit.

inverse = region.inverse;
T = double(inverse.T);
projector = T * T';
try, labs = inverse.trials; catch, labs = D.condlist; end
if ischar(labs) || isstring(labs), labs = cellstr(labs); end
good = D.indtrial(labs{1}, 'GOOD');
if numel(good) < cfg.minimum_good_epochs
    error('V37:EpochCount', 'Only %d good epochs.', numel(good));
end
try, scale = inverse.scale; catch, scale = 1; end
if numel(scale) > 1, scale = scale(1); end

fs = double(D.fsample);
ntime = numel(inverse.It);
w = min(fix(cfg.spectral_window_seconds * fs), ntime);
if w < 16, error('V37:Window', 'Spectral window is too short.'); end
nwindows = max(8 * (fix(ntime / w) - 1), 1);
starts = 1 + fix((0:nwindows-1) * w / 8);
starts(starts + w - 1 > ntime) = [];
taper = 0.5 - 0.5*cos(2*pi*(0:w-1)/max(w-1,1));
bins = round(cfg.frequency_hz * w / fs) + 1;
if any(bins > w), error('V37:Frequency', 'Requested frequency exceeds FFT grid.'); end

nm = cfg.regional_spatial_modes;
npatch = size(region.filters,1) / nm;
nf = numel(cfg.frequency_hz);
all_power = zeros(npatch, nf);
odd_power = zeros(npatch, nf);
even_power = zeros(npatch, nf);
nall = 0; nodd = 0; neven = 0;

for e = 1:numel(good)
    raw = double(D(region.inverse_channels, inverse.It, good(e)));
    Z = (region.filters * (raw * projector)) * double(scale);
    for k = 1:numel(starts)
        iw = starts(k) + (0:w-1);
        F = fft(Z(:,iw) .* taper, [], 2);
        P = reshape(abs(F(:,bins)).^2, nm, npatch, nf);
        P = squeeze(mean(P, 1)) / max(sum(taper.^2) * fs, eps);
        all_power = all_power + P; nall = nall + 1;
        if mod(e,2)
            odd_power = odd_power + P; nodd = nodd + 1;
        else
            even_power = even_power + P; neven = neven + 1;
        end
    end
end

all_power = all_power / max(nall,1);
odd_power = odd_power / max(nodd,1);
even_power = even_power / max(neven,1);
floor_value = realmin('single');
log_spectrum = log(max(all_power, floor_value));
split_corr = nan(npatch,1);
for p = 1:npatch
    split_corr(p) = local_corr(log(max(odd_power(p,:),floor_value))', ...
        log(max(even_power(p,:),floor_value))');
end

lf = log(double(cfg.frequency_hz(:)));
X = [ones(nf,1), lf];
b = X \ log_spectrum';
detrended = log_spectrum - (X*b)';
[peak_prominence, peak_index] = max(detrended, [], 2);
power_sum = sum(all_power, 2);
prob = all_power ./ max(power_sum, eps);

spectral = struct();
spectral.frequency_hz = double(cfg.frequency_hz(:)');
spectral.log_spectrum = single(log_spectrum);
spectral.log_integrated_power = log(max(trapz(cfg.frequency_hz,all_power,2),floor_value));
spectral.spectral_intercept = b(1,:)';
spectral.spectral_slope = b(2,:)';
spectral.spectral_centroid_hz = sum(all_power .* cfg.frequency_hz,2) ./ max(power_sum,eps);
spectral.spectral_entropy = -sum(prob .* log(max(prob,eps)),2) / log(nf);
spectral.peak_frequency_hz = cfg.frequency_hz(peak_index)';
spectral.peak_prominence = peak_prominence;
spectral.split_half_spectral_correlation = split_corr;
spectral.n_good_epochs = numel(good);
spectral.n_windows_per_epoch = numel(starts);
spectral.fsample = fs;
end

function r = local_corr(a,b)
a = a - mean(a); b = b - mean(b);
r = (a' * b) / sqrt(max((a'*a)*(b'*b), eps));
end
