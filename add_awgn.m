function y = add_awgn(x, snr_db)
% Add complex AWGN to signal at given SNR (dB)
%   x      - input complex baseband signal
%   snr_db - signal-to-noise ratio in dB
%   y      - noisy output signal
    signal_power = mean(abs(x(:)).^2);
    noise_power = signal_power * 10^(-snr_db / 10);
    noise = sqrt(noise_power / 2) * (randn(size(x)) + 1j * randn(size(x)));
    y = x + noise;
end
