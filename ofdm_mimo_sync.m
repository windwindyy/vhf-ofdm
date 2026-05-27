function [rx1_sync, rx2_sync, frame_start, freq_offset] = ofdm_mimo_sync(rx1, rx2, cfg)
% MIMO time + frequency synchronization
% Time sync: both RX antennas use TX1's training symbol (cross-correlation)
% Freq sync: use TX1's training (sym 1) and TX1's pilot (sym 3)
%   The pilot is 2*sym_len after training (TX2's training is between them)

    fs      = 1e6;
    cp_len  = cfg.cp_len;
    N_fft   = cfg.N_fft;
    sym_len = cfg.sym_len;

    % --- Time sync: both RX antennas vs TX1 training ---
    cfg_time = cfg;
    cfg_time.train_tx = cfg.train_tx_1;
    fs1 = ofdm_time_sync(rx1, cfg_time);
    fs2 = ofdm_time_sync(rx2, cfg_time);
    frame_start = min(fs1, fs2);

    fprintf('MIMO time sync: RX1@%d  RX2@%d  using TX1 training\n', fs1, fs2);

    % --- Freq sync: TX1 training (sym 0) vs TX1 first pilot ---
    % First pilot group at cfg.pilot_group_pos(1); TX1 pilot is its first symbol
    train_start = frame_start + cp_len;
    train_end   = frame_start + sym_len - 1;
    pilot_sym   = cfg.pilot_group_pos(1);  % frame symbol index of TX1's first pilot
    pilot_start = frame_start + pilot_sym * sym_len + cp_len;
    pilot_end   = frame_start + (pilot_sym + 1) * sym_len - 1;
    T = pilot_sym * sym_len / fs;  % time between training and first pilot

    if pilot_end > length(rx1)
        error('Pilot symbol extends beyond RX1 signal');
    end

    Y_train = fft(rx1(train_start : train_end), N_fft) / sqrt(N_fft);
    Y_pilot = fft(rx1(pilot_start : pilot_end), N_fft) / sqrt(N_fft);

    Yt_act = [Y_train(cfg.idx_data1); Y_train(cfg.idx_data2)];
    Yp_act = [Y_pilot(cfg.idx_data1); Y_pilot(cfg.idx_data2)];

    Ht = Yt_act ./ cfg.train_syms_1(:);
    Hp = Yp_act ./ cfg.pilot_syms_1(:);

    % Phase between training and pilot
    phase_diff = sum(Hp .* conj(Ht));
    freq_offset = angle(phase_diff) / (2 * pi * T);

    % --- Correction ---
    t1 = (0 : length(rx1) - 1)' / fs;
    t2 = (0 : length(rx2) - 1)' / fs;
    rx1_sync = rx1(:) .* exp(-1j * 2 * pi * freq_offset * t1);
    rx2_sync = rx2(:) .* exp(-1j * 2 * pi * freq_offset * t2);

    phase_per_subc = angle(Hp .* conj(Ht)) * 180 / pi;
    fprintf('MIMO freq sync: CFO = %.3f Hz (%.2f ppm)\n', ...
            freq_offset, freq_offset / 100e6 * 1e6);
    fprintf('  TX1 train→pilot: %d subc, phase mean=%.2f deg  std=%.2f deg\n', ...
            cfg.N_active, mean(phase_per_subc), std(phase_per_subc));
end
