function H_data = mimo_channel_est(rx1_sync, rx2_sync, cfg, frame_start)
% MIMO 2×2 periodic channel estimation with MMSE + linear interpolation.
% Uses time-division pilots at cfg.pilot_group_pos.
%   H_data - struct array, H_data(d) has .h11,.h12,.h21,.h22 for data symbol d

    cp_len  = cfg.cp_len;
    N_fft   = cfg.N_fft;
    sym_len = cfg.sym_len;
    N_active = cfg.N_active;
    pg_pos  = cfg.pilot_group_pos;  % start symbol index of each pilot group
    n_pg    = length(pg_pos);

    % --- Build R_HH, estimate sigma2 (same for all pilots) ---
    delays_us = [0, 0.2, 0.5, 1.0, 2.0];
    powers_db = [0, -3, -6, -9, -12];
    powers_lin = 10.^(powers_db/10);
    powers_lin = powers_lin / sum(powers_lin);
    delta_f = 1e6 / N_fft;
    R_HH = zeros(N_active);
    for p = 1:length(delays_us)
        tau = delays_us(p) * 1e-6;
        k_idx = (0:N_active-1)'; l_idx = (0:N_active-1);
        R_HH = R_HH + powers_lin(p) * exp(-1j*2*pi*delta_f*tau*(k_idx-l_idx));
    end

    p0 = frame_start + pg_pos(1)*sym_len + cp_len;
    Y0 = fft(rx1_sync(p0 : p0+N_fft-1), N_fft) / sqrt(N_fft);
    guard_bins = [1, (2:56), 257, (458:512)];
    sigma2 = max(mean(abs(Y0(guard_bins)).^2), 1e-10);
    W = R_HH / (R_HH + sigma2 * eye(N_active));

    % --- MMSE at each pilot group ---
    H_pg = struct('h11', cell(1,n_pg), 'h12', cell(1,n_pg), ...
                 'h21', cell(1,n_pg), 'h22', cell(1,n_pg));
    for g = 1:n_pg
        % Pilot group at pg_pos(g): TX1 pilot then TX2 pilot
        p1_start = frame_start + pg_pos(g) * sym_len + cp_len;
        p1_end   = p1_start + N_fft - 1;
        p2_start = frame_start + (pg_pos(g)+1) * sym_len + cp_len;
        p2_end   = p2_start + N_fft - 1;

        % TX1 pilot → H11, H21
        Y1_r1 = fft(rx1_sync(p1_start:p1_end), N_fft) / sqrt(N_fft);
        Y1_r2 = fft(rx2_sync(p1_start:p1_end), N_fft) / sqrt(N_fft);
        Y1a_r1 = [Y1_r1(cfg.idx_data1); Y1_r1(cfg.idx_data2)];
        Y1a_r2 = [Y1_r2(cfg.idx_data1); Y1_r2(cfg.idx_data2)];
        H_pg(g).h11 = W * (Y1a_r1 ./ cfg.pilot_syms_1(:));
        H_pg(g).h21 = W * (Y1a_r2 ./ cfg.pilot_syms_1(:));

        % TX2 pilot → H12, H22
        Y2_r1 = fft(rx1_sync(p2_start:p2_end), N_fft) / sqrt(N_fft);
        Y2_r2 = fft(rx2_sync(p2_start:p2_end), N_fft) / sqrt(N_fft);
        Y2a_r1 = [Y2_r1(cfg.idx_data1); Y2_r1(cfg.idx_data2)];
        Y2a_r2 = [Y2_r2(cfg.idx_data1); Y2_r2(cfg.idx_data2)];
        H_pg(g).h12 = W * (Y2a_r1 ./ cfg.pilot_syms_2(:));
        H_pg(g).h22 = W * (Y2a_r2 ./ cfg.pilot_syms_2(:));
    end

    % --- Map data symbols to interpolated channel ---
    n_data = cfg.n_data_syms;
    H_data = struct('h11', cell(1,n_data), 'h12', cell(1,n_data), ...
                    'h21', cell(1,n_data), 'h22', cell(1,n_data));

    d = 0;  % data symbol counter (0-indexed)
    for g = 1:n_pg-1
        % Pilot group g is at pg_pos(g), group g+1 at pg_pos(g+1)
        % Between them: pg_pos(g)+2 data start, pg_pos(g+1)-1 data end
        gap = pg_pos(g+1) - pg_pos(g) - 2;  % -2 for the 2 pilot symbols

        for s = 1:gap
            if d >= n_data, break; end
            alpha = (s - 0.5) / gap;
            H_data(d+1).h11 = (1-alpha)*H_pg(g).h11 + alpha*H_pg(g+1).h11;
            H_data(d+1).h12 = (1-alpha)*H_pg(g).h12 + alpha*H_pg(g+1).h12;
            H_data(d+1).h21 = (1-alpha)*H_pg(g).h21 + alpha*H_pg(g+1).h21;
            H_data(d+1).h22 = (1-alpha)*H_pg(g).h22 + alpha*H_pg(g+1).h22;
            d = d + 1;
        end
        if d >= n_data, break; end
    end

    % Remaining data symbols (after last pilot) → use last pilot estimate
    while d < n_data
        H_data(d+1).h11 = H_pg(end).h11;
        H_data(d+1).h12 = H_pg(end).h12;
        H_data(d+1).h21 = H_pg(end).h21;
        H_data(d+1).h22 = H_pg(end).h22;
        d = d + 1;
    end

    fprintf('MIMO channel est (periodic MMSE): %d pilot groups, sigma2=%.2e\n', n_pg, sigma2);
    fprintf('  Interpolated to %d data symbols\n', n_data);
end
