function H_data = mimo_channel_est(rx1_sync, rx2_sync, cfg, frame_start)
% MIMO 2×2 channel estimation: LS + moving-average smoothing + linear interpolation.
% Time-division pilots at cfg.pilot_group_pos.

    cp_len  = cfg.cp_len;
    N_fft   = cfg.N_fft;
    sym_len = cfg.sym_len;
    N_active = cfg.N_active;
    pg_pos  = cfg.pilot_group_pos;
    n_pg    = length(pg_pos);

    % Moving-average half-window (total window = 2*w+1 subcarriers)
    w = 8;

    % --- LS + moving-average at each pilot group ---
    H_pg = struct('h11', cell(1,n_pg), 'h12', cell(1,n_pg), ...
                  'h21', cell(1,n_pg), 'h22', cell(1,n_pg));
    for g = 1:n_pg
        % TX1 pilot → H11, H21
        p1_start = frame_start + pg_pos(g) * sym_len + cp_len;
        p1_end   = p1_start + N_fft - 1;
        Y1_r1 = fft(rx1_sync(p1_start:p1_end), N_fft) / sqrt(N_fft);
        Y1_r2 = fft(rx2_sync(p1_start:p1_end), N_fft) / sqrt(N_fft);
        Y1a_r1 = [Y1_r1(cfg.idx_data1); Y1_r1(cfg.idx_data2)];
        Y1a_r2 = [Y1_r2(cfg.idx_data1); Y1_r2(cfg.idx_data2)];
        H_pg(g).h11 = movmean(Y1a_r1 ./ cfg.pilot_syms_1(:), 2*w+1);
        H_pg(g).h21 = movmean(Y1a_r2 ./ cfg.pilot_syms_1(:), 2*w+1);

        % TX2 pilot → H12, H22
        p2_start = frame_start + (pg_pos(g)+1) * sym_len + cp_len;
        p2_end   = p2_start + N_fft - 1;
        Y2_r1 = fft(rx1_sync(p2_start:p2_end), N_fft) / sqrt(N_fft);
        Y2_r2 = fft(rx2_sync(p2_start:p2_end), N_fft) / sqrt(N_fft);
        Y2a_r1 = [Y2_r1(cfg.idx_data1); Y2_r1(cfg.idx_data2)];
        Y2a_r2 = [Y2_r2(cfg.idx_data1); Y2_r2(cfg.idx_data2)];
        H_pg(g).h12 = movmean(Y2a_r1 ./ cfg.pilot_syms_2(:), 2*w+1);
        H_pg(g).h22 = movmean(Y2a_r2 ./ cfg.pilot_syms_2(:), 2*w+1);
    end

    % --- Linear interpolation to data symbols ---
    n_data = cfg.n_data_syms;
    H_data = struct('h11', cell(1,n_data), 'h12', cell(1,n_data), ...
                    'h21', cell(1,n_data), 'h22', cell(1,n_data));

    d = 0;
    for g = 1:n_pg-1
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

    % After last pilot → reuse last pilot estimate
    while d < n_data
        H_data(d+1).h11 = H_pg(end).h11;
        H_data(d+1).h12 = H_pg(end).h12;
        H_data(d+1).h21 = H_pg(end).h21;
        H_data(d+1).h22 = H_pg(end).h22;
        d = d + 1;
    end

    fprintf('MIMO channel est (LS + movmean w=%d): %d pilot groups, %d data symbols\n', ...
            w, n_pg, n_data);
end
