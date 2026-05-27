function H_mmse = channel_estimate_mmse(rx_signal, cfg, frame_start, snr_db)
% MMSE Channel Estimation using block-type pilot
%   rx_signal   - received time-domain signal (after sync)
%   cfg         - OFDM config (from ofdm_config / ofdm_assemble_frame)
%   frame_start - frame start sample from time sync
%   snr_db      - estimated SNR (dB), used for MMSE regularization
%   H_mmse      - 400×1 estimated channel frequency response

    % --- Step 1: Extract pilot symbol (2nd OFDM symbol in frame) ---
    pilot_start = frame_start + cfg.sym_len;
    pilot_body = rx_signal(pilot_start + cfg.cp_len : pilot_start + cfg.sym_len - 1);

    % --- Step 2: FFT to frequency domain ---
    Y_freq = fft(pilot_body, cfg.N_fft) / sqrt(cfg.N_fft);

    % --- Step 3: Extract active subcarriers ---
    Y_active = [Y_freq(cfg.idx_data1); Y_freq(cfg.idx_data2)];

    % --- Step 4: LS initial estimate ---
    H_ls = Y_active ./ cfg.pilot_syms(:);

    % --- Step 5: Estimate noise variance from guard bands ---
    % DC (bin 1), guard_left (bins 2:56), Nyquist (bin 257), guard_right (bins 458:512)
    guard_bins = [1, (2:56), 257, (458:512)];
    noise_power = mean(abs(Y_freq(guard_bins)).^2);
    sigma2 = max(noise_power, 1e-10);

    % --- Step 6: Build frequency correlation matrix R_HH ---
    % Known PDP: delays [0, 0.2, 0.5, 1.0, 2.0] us, powers [0,-3,-6,-9,-12] dB
    delays_us = [0, 0.2, 0.5, 1.0, 2.0];
    powers_db = [0, -3, -6, -9, -12];
    powers_lin = 10.^(powers_db / 10);
    powers_lin = powers_lin / sum(powers_lin);
    delta_f = 1e6 / cfg.N_fft;  % 1953.125 Hz
    N_active = cfg.N_active;

    R_HH = zeros(N_active, N_active);
    for p = 1:length(delays_us)
        tau = delays_us(p) * 1e-6;
        % Each path contributes a rank-1 Toeplitz component
        k_idx = (0:N_active-1)';
        l_idx = (0:N_active-1);
        phase = exp(-1j * 2 * pi * delta_f * tau * (k_idx - l_idx));
        R_HH = R_HH + powers_lin(p) * phase;
    end

    % --- Step 7: MMSE smoothing ---
    % H_mmse = R_HH * (R_HH + sigma2 * I)^(-1) * H_ls
    beta = sigma2;  % regularization; scale by SNR for robustness
    H_mmse = R_HH * ((R_HH + beta * eye(N_active)) \ H_ls);

    fprintf('\n===== MMSE Channel Estimation =====\n');
    fprintf('LS pilot power:   %.4f (avg |H_ls|^2)\n', mean(abs(H_ls).^2));
    fprintf('Noise variance:   %.3e (from guard bands)\n', sigma2);
    fprintf('MMSE gain (|H|^2): %.4f -> %.4f\n', mean(abs(H_ls).^2), mean(abs(H_mmse).^2));
    fprintf('Freq correlation: cond(R_HH) = %.1f\n', cond(R_HH));
end
