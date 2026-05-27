function h = rayleigh_fading(N, fd, fs)
% Generate Rayleigh fading coefficients using filtered Gaussian noise.
% Jakes-like Doppler spectrum approximated by FIR lowpass filter.
%
%   N   - number of samples at full rate
%   fd  - maximum Doppler shift (Hz)
%   fs  - sampling rate (Hz)
%   h   - 1×N complex fading coefficients, unit average power

    if fd < 1e-6
        h = ones(1, N);
        return;
    end

    % Sample fading at ~10× the Doppler rate (Nyquist = 2*fd)
    fs_fade = max(50, ceil(10 * fd));   % ~55 Hz for fd=5.56
    N_fade = max(256, ceil(N * fs_fade / fs));

    % Design Doppler FIR lowpass filter
    nfilt = min(128, floor(N_fade / 4));
    % cutoff = fd / (fs_fade/2);
    % Brute force check for valid cutoff range since fd may be very small relative to fs_fade
    cutoff = fd / (fs_fade / 2);
    if cutoff <= 0 || cutoff >= 1
        h = ones(1, N);
        return;
    end

    b = fir1(nfilt, cutoff);

    % Generate complex Gaussian noise, filter to impose Doppler spectrum
    noise = (randn(1, N_fade + nfilt) + 1j * randn(1, N_fade + nfilt)) / sqrt(2);
    h_low = filter(b, 1, noise);
    h_low = h_low(nfilt + 1 : end);       % discard filter transient

    % Interpolate real/imag separately (pchip does not support complex)
    t_low  = (0 : length(h_low) - 1) / fs_fade;
    t_full = (0 : N - 1) / fs;
    h_real = interp1(t_low, real(h_low), t_full, 'pchip');
    h_imag = interp1(t_low, imag(h_low), t_full, 'pchip');
    h = h_real + 1j * h_imag;
    % Normalize to unit average power
    h = h / sqrt(mean(abs(h).^2));

    fprintf('Rayleigh fading: fd=%.2f Hz, fs=%.1f Hz, %d samples\n', fd, fs, N);
end
