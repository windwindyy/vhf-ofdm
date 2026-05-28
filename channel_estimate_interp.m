function H_data = channel_estimate_interp(rx_sync, cfg, frame_start, snr_db)
% Periodic channel estimation: LS + moving-average smoothing + linear interpolation.
%   snr_db    - SNR (dB), unused (kept for signature compatibility)

    cp_len  = cfg.cp_len;
    sym_len = cfg.sym_len;
    N_active = cfg.N_active;
    pilot_pos = cfg.pilot_positions;
    n_pilots = length(pilot_pos);

    % Moving-average half-window (total window = 2*w+1 subcarriers)
    w = 8;

    % --- LS + moving-average at each pilot ---
    H_pilots = zeros(N_active, n_pilots);
    for i = 1:n_pilots
        p_start = frame_start + pilot_pos(i) * sym_len + cp_len;
        p_end   = frame_start + (pilot_pos(i)+1) * sym_len - 1;
        Y = fft(rx_sync(p_start:p_end), cfg.N_fft) / sqrt(cfg.N_fft);
        Y_act = [Y(cfg.idx_data1); Y(cfg.idx_data2)];
        H_ls = Y_act ./ cfg.pilot_syms(:);
        H_pilots(:, i) = movmean(H_ls, 2*w+1);  % sliding window, shrink at edges
    end

    % --- Linear interpolation to data symbols ---
    n_data = cfg.n_data_syms;
    H_data = zeros(N_active, n_data);

    d = 0;
    for g = 1:n_pilots-1
        p_left  = pilot_pos(g);
        p_right = pilot_pos(g+1);
        gap = p_right - p_left - 1;

        for s = 1:gap
            if d >= n_data, break; end
            alpha = (s - 1) / max(gap, 1);
            H_data(:, d+1) = (1-alpha) * H_pilots(:, g) + alpha * H_pilots(:, g+1);
            d = d + 1;
        end
        if d >= n_data, break; end
    end

    % Single pilot → reuse for all data symbols
    if n_pilots == 1
        for d = 1:n_data
            H_data(:, d) = H_pilots(:, 1);
        end
    end

    fprintf('Channel est (LS + movmean w=%d): %d pilots, %d data symbols\n', ...
            w, n_pilots, n_data);
end
