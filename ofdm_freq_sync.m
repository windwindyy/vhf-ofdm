function [rx_corrected, freq_offset] = ofdm_freq_sync(rx_signal, cfg, frame_start)
% Frequency-domain CFO estimation using known training and pilot symbols.
% Compares channel estimates from consecutive OFDM symbols in frequency
% domain — avoids multipath cross-term interference of time-domain CP method.
%
%   rx_signal     - received baseband signal (with CFO)
%   cfg           - OFDM config (must contain .train_syms, .pilot_syms)
%   frame_start   - frame start sample from time sync
%   rx_corrected  - frequency-corrected signal
%   freq_offset   - estimated frequency offset (Hz)
%
% Principle:
%   H_train[k] = Y_train[k] / X_train[k]  (known BPSK)
%   H_pilot[k] = Y_pilot[k] / X_pilot[k]  (known BPSK)
%   H_pilot / H_train = exp(j·2π·Δf·T_sym) per subcarrier
%   Average across all 400 subcarriers for high-accuracy estimate.

    cp_len  = cfg.cp_len;
    N_fft   = cfg.N_fft;
    sym_len = cfg.sym_len;
    fs      = 1e6;

    % --- Extract training symbol FFT body (skip CP) ---
    t_start = frame_start + cp_len;
    t_end   = frame_start + sym_len - 1;
    if t_end > length(rx_signal)
        error('Training symbol extends beyond signal length');
    end
    Y_train = fft(rx_signal(t_start : t_end), N_fft) / sqrt(N_fft);
    Y_train_active = [Y_train(cfg.idx_data1); Y_train(cfg.idx_data2)];

    % --- Extract pilot symbol FFT body (skip CP) ---
    p_start = frame_start + sym_len + cp_len;
    p_end   = frame_start + 2 * sym_len - 1;
    if p_end > length(rx_signal)
        error('Pilot symbol extends beyond signal length');
    end
    Y_pilot = fft(rx_signal(p_start : p_end), N_fft) / sqrt(N_fft);
    Y_pilot_active = [Y_pilot(cfg.idx_data1); Y_pilot(cfg.idx_data2)];

    % --- Channel estimates from known BPSK training/pilot symbols ---
    H_train = Y_train_active ./ cfg.train_syms(:);
    H_pilot = Y_pilot_active ./ cfg.pilot_syms(:);

    % --- Phase difference: H_pilot[k] · H_train*[k] = |H[k]|² · exp(j·2π·Δf·T_sym) ---
    phase_diff = sum(H_pilot .* conj(H_train));

    % --- CFO estimate ---
    T_sym = sym_len / fs;  % one OFDM symbol duration (520 μs)
    freq_offset = angle(phase_diff) / (2 * pi * T_sym);

    % --- Correction ---
    t = (0 : length(rx_signal) - 1)' / fs;
    rx_corrected = rx_signal(:) .* exp(-1j * 2 * pi * freq_offset * t);

    % --- Diagnostics ---
    phase_per_subc = angle(H_pilot .* conj(H_train)) * 180 / pi;
    fprintf('Freq sync (freq-domain): CFO = %.3f Hz (%.2f ppm @ 100 MHz)\n', ...
            freq_offset, freq_offset / 100e6 * 1e6);
    fprintf('  %d active subcarriers | Phase/sym mean=%.2f deg  std=%.2f deg\n', ...
            cfg.N_active, mean(phase_per_subc), std(phase_per_subc));
end
