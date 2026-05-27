function H_data = channel_estimate_interp(rx_sync, cfg, frame_start, snr_db)
% Periodic channel estimation with MMSE at pilots + linear interpolation.
%   rx_sync   - frequency-corrected signal
%   cfg       - OFDM config (must have .pilot_positions, .pilot_syms)
%   frame_start - frame start sample
%   snr_db    - SNR (for MMSE regularization)
%   H_data    - 400 × n_data_syms matrix, channel estimate per data symbol

    cp_len  = cfg.cp_len;
    N_fft   = cfg.N_fft;
    sym_len = cfg.sym_len;
    N_active = cfg.N_active;
    pilot_pos = cfg.pilot_positions;  % symbol indices of pilots (1-indexed after train)
    n_pilots = length(pilot_pos);

    % --- Build R_HH once (same for all pilots) ---
    delays_us = [0, 0.2, 0.5, 1.0, 2.0];
    powers_db = [0, -3, -6, -9, -12];
    powers_lin = 10.^(powers_db / 10);
    powers_lin = powers_lin / sum(powers_lin);
    delta_f = 1e6 / N_fft;

    R_HH = zeros(N_active);
    for p = 1:length(delays_us)
        tau = delays_us(p) * 1e-6;
        k_idx = (0:N_active-1)';
        l_idx = (0:N_active-1);
        R_HH = R_HH + powers_lin(p) * exp(-1j*2*pi*delta_f*tau*(k_idx-l_idx));
    end

    % --- Estimate sigma2 from guard bands of first pilot ---
    p0_start = frame_start + pilot_pos(1) * sym_len + cp_len;
    p0_end   = frame_start + (pilot_pos(1)+1) * sym_len - 1;
    Y0 = fft(rx_sync(p0_start:p0_end), N_fft) / sqrt(N_fft);
    guard_bins = [1, (2:56), 257, (458:512)];
    sigma2 = max(mean(abs(Y0(guard_bins)).^2), 1e-10);

    W = R_HH / (R_HH + sigma2 * eye(N_active));  % MMSE smoothing matrix

    % --- MMSE estimate at each pilot ---
    H_pilots = zeros(N_active, n_pilots);
    for i = 1:n_pilots
        p_start = frame_start + pilot_pos(i) * sym_len + cp_len;
        p_end   = frame_start + (pilot_pos(i)+1) * sym_len - 1;
        Y = fft(rx_sync(p_start:p_end), N_fft) / sqrt(N_fft);
        Y_act = [Y(cfg.idx_data1); Y(cfg.idx_data2)];
        H_ls = Y_act ./ cfg.pilot_syms(:);
        H_pilots(:, i) = W * H_ls;
    end

    % --- Interpolate to data symbols ---
    % Data symbols start after the last overhead symbol.
    % In a periodic frame: Train | Pilot_0 | D_1..D_K | Pilot_1 | D_{K+1}..D_{2K} | ...
    % Data symbol d (0-indexed) is at frame symbol index = overhead_before + d
    % We need to map each data symbol to the nearest pilots.

    n_data = cfg.n_data_syms;
    H_data = zeros(N_active, n_data);

    % Map data symbol index to pilots. Pilot i is at symbol position pilot_pos(i).
    % Data symbol d (0-indexed): the d-th data symbol in the frame.
    % In a periodic frame, data symbols are between pilots.

    d = 0;  % counter for data symbol index (0-indexed)
    for g = 1:n_pilots-1
        p_left  = pilot_pos(g);
        p_right = pilot_pos(g+1);
        gap = p_right - p_left - 1;  % number of data symbols between these two pilots

        for s = 1:gap
            if d >= n_data, break; end
            alpha = (s - 1) / max(gap, 1);  % 0 at left pilot, approaches 1 at right pilot
            H_data(:, d+1) = (1-alpha) * H_pilots(:, g) + alpha * H_pilots(:, g+1);
            d = d + 1;
        end
        if d >= n_data, break; end
    end

    % If only one pilot (single-pilot mode), use it for all data symbols
    if n_pilots == 1
        for d = 1:n_data
            H_data(:, d) = H_pilots(:, 1);
        end
    end

    fprintf('Channel est (periodic): %d pilots, sigma2=%.2e\n', n_pilots, sigma2);
    fprintf('  Interpolation to %d data symbols (%.1f ms span)\n', ...
            n_data, n_data * sym_len / 1e3);
end
