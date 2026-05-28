function main(antenna_scheme, snr_val, N_val)
% main.m — VHF OFDM Communication System Simulator (Group 2)
% Combines SISO and MIMO 2×2 Alamouti with auto-modulation selection.
%
% Usage:
%   main                  — interactive menu
%   main('siso')          — SISO with default SNR=20 dB
%   main('mimo')          — MIMO with default SNR=20 dB
%   main('siso', snr)     — SISO with specified SNR
%   main('mimo', snr, N)  — MIMO with specified SNR and N bits

    close all;

    % ========================================================================
    % 0. Argument Parsing & Menu
    % ========================================================================
    if nargin < 1 || isempty(antenna_scheme)
        fprintf('=============================================================\n');
        fprintf('  VHF OFDM Communication System Simulator — Group 2\n');
        fprintf('  Carrier: 100 MHz | BW: 1 MHz | Speed: 60 km/h\n');
        fprintf('  Channel: 5-path military vehicular (fd = 5.56 Hz)\n');
        fprintf('=============================================================\n\n');
        fprintf('Select simulation mode:\n');
        fprintf('  [1] SISO  — Single-antenna OFDM system\n');
        fprintf('  [2] MIMO  — 2×2 Alamouti STBC OFDM system\n');
        fprintf('  [0] Exit\n\n');
        choice = input('Enter choice (0-2): ');
        switch choice
            case 1, antenna_scheme = 'siso';
            case 2, antenna_scheme = 'mimo';
            case 0, fprintf('Exiting.\n'); return;
            otherwise, fprintf('Invalid choice.\n'); return;
        end
    end
    is_siso = strcmpi(antenna_scheme, 'siso');
    is_mimo = strcmpi(antenna_scheme, 'mimo');
    if ~is_siso && ~is_mimo
        error('antenna_scheme must be ''siso'' or ''mimo''');
    end

    % ========================================================================
    % 1. Global Parameters
    % ========================================================================
    if nargin < 3 || isempty(N_val), N = 1000000; else, N = N_val; end
    frame_len = 1024;       % Data bits per frame (CRC unit)
    crc_len   = 16;         % CRC checksum length
    cfo_hz    = 10;         % Carrier Frequency Offset (0.1 ppm @ 100 MHz)
    pilot_spacing = 40;     % Data symbols between periodic pilots

    if nargin < 2 || isempty(snr_val)
        snr_db = 10 ;
    else
        snr_db = snr_val;
    end

    % Auto-select modulation based on SNR and antenna scheme
    mod_type = auto_select_modulation(snr_db, antenna_scheme);

    fprintf('\n===== %s OFDM Simulation =====\n', upper(antenna_scheme));
    fprintf('Source bits: %d\n', N);
    fprintf('Frame data:  %d bits  |  CRC: %d bits\n', frame_len, crc_len);
    fprintf('Antenna:     %s\n', antenna_scheme);
    fprintf('Modulation:  %s (auto-selected)\n', mod_type);
    fprintf('CFO inject:  %.1f Hz (%.2f ppm @ 100 MHz)\n', cfo_hz, cfo_hz/100e6*1e6);
    fprintf('AWGN SNR:    %.0f dB\n', snr_db);

    % ========================================================================
    % 2. Common TX Chain: Source → CRC → Encode → Interleave → Modulate
    % ========================================================================
    fprintf('\n===== TX Chain =====\n');

    bits = generate_source(N);
    fprintf('Source: %d bits (0-ratio: %.3f, 1-ratio: %.3f)\n', ...
            length(bits), mean(bits==0), mean(bits==1));

    tx_bits = crc16_encode(bits, frame_len);
    n_frames = ceil(N / frame_len);
    expected_len = n_frames * (frame_len + crc_len);
    fprintf('CRC-16:  %d → %d bits (%d frames)\n', N, length(tx_bits), n_frames);

    coded_bits = channel_encode(tx_bits);
    fprintf('Conv encode (K=7,R=1/2): %d → %d bits\n', length(tx_bits), length(coded_bits));

    [int_bits, perm] = interleave(coded_bits);

    bpsym_map = containers.Map({'QPSK','16QAM','64QAM'}, [2, 4, 6]);
    bpsym = bpsym_map(upper(mod_type));
    tx_symbols = modulate(int_bits, mod_type);
    n_sym = floor(length(int_bits) / bpsym);
    fprintf('Modulation (%s): %d bits → %d symbols\n', mod_type, length(int_bits), n_sym);

    % Verify modulation roundtrip
    rx_bits_mod = demodulate(tx_symbols, mod_type);
    assert(isequal(rx_bits_mod, int_bits(1:length(rx_bits_mod))), ...
           'Modulation/demodulation not inverse');
    fprintf('[PASS] TX chain complete\n');

    % ========================================================================
    % 3. OFDM Frame Assembly (branch on SISO vs MIMO)
    % ========================================================================
    fprintf('\n===== OFDM Frame Assembly (%s) =====\n', upper(antenna_scheme));

    if is_siso
        [tx_frame, ofdm_cfg] = ofdm_assemble_frame(int_bits, mod_type, pilot_spacing);
        expected_sym_len = 520;
        tx_frame_len = length(tx_frame);
        n_symbols = tx_frame_len / expected_sym_len;
        assert(mod(tx_frame_len, expected_sym_len) == 0, ...
               'Frame length not multiple of symbol length');
        fprintf('Frame: %d samples, %d OFDM symbols (train + pilot + data)\n', ...
                tx_frame_len, n_symbols);
    else
        [tx1, tx2, cfg] = mimo_ofdm_assemble_frame(int_bits, mod_type, pilot_spacing);
        expected_sym_len = cfg.sym_len;
        fprintf('MIMO frames: TX1=%d, TX2=%d samples\n', length(tx1), length(tx2));
    end

    % ========================================================================
    % 4. Channel + CFO + AWGN (branch on SISO vs MIMO)
    % ========================================================================
    fprintf('\n===== Channel + Impairments =====\n');

    if is_siso
        % --- SISO Channel ---
        [rx_signal, chan] = vhf_channel(tx_frame);
        rx_chan_only = rx_signal;  % before CFO, for true channel comparison

        % CFO injection
        if cfo_hz ~= 0
            fs = 1e6;
            t_vec = (0 : length(rx_signal) - 1)' / fs;
            rx_signal = rx_signal .* exp(1j * 2 * pi * cfo_hz * t_vec);
            fprintf('CFO injected: %.1f Hz\n', cfo_hz);
        end

        rx_nonoise = rx_signal;
        rx_power = mean(abs(rx_nonoise).^2);
        rx_signal = add_awgn(rx_signal, snr_db);
        fprintf('AWGN added: SNR = %.0f dB\n', snr_db);

    else
        % --- MIMO Channel ---
        [rx1, rx2] = mimo_channel(tx1, tx2);

        fs = 1e6;
        rx_power = (mean(abs(rx1).^2) + mean(abs(rx2).^2)) / 2;

        if cfo_hz ~= 0
            t1 = (0 : length(rx1) - 1)' / fs;
            t2 = (0 : length(rx2) - 1)' / fs;
            rx1 = rx1 .* exp(1j * 2 * pi * cfo_hz * t1);
            rx2 = rx2 .* exp(1j * 2 * pi * cfo_hz * t2);
            fprintf('CFO injected: %.1f Hz\n', cfo_hz);
        end

        rx1_clean = rx1;  % before AWGN, for true channel comparison
        rx2_clean = rx2;

        rx1 = add_awgn(rx1, snr_db);
        rx2 = add_awgn(rx2, snr_db);
        fprintf('AWGN added: SNR = %d dB per antenna\n', snr_db);
    end

    % ========================================================================
    % 5. RX: Sync + Channel Estimation + Equalization
    % ========================================================================
    fprintf('\n===== RX Processing (%s) =====\n', upper(antenna_scheme));

    if is_siso
        % --- SISO Time + Frequency Sync ---
        frame_start = ofdm_time_sync(rx_signal, ofdm_cfg);
        assert(frame_start < 500, 'Frame start too late: sample %d', frame_start);

        [rx_sync, freq_offset] = ofdm_freq_sync(rx_signal, ofdm_cfg, frame_start);
        fprintf('Estimated CFO: %.2f Hz\n', freq_offset);

        % --- SISO Channel Estimation (Periodic MMSE + Interpolation) ---
        H_data = channel_estimate_interp(rx_sync, ofdm_cfg, frame_start, snr_db);
        assert(size(H_data,1) == ofdm_cfg.N_active, 'Channel estimate dimension mismatch');

        % True channel from noiseless signal at first pilot
        p0 = ofdm_cfg.pilot_positions(1);
        p_body = rx_chan_only(frame_start + p0*ofdm_cfg.sym_len + ofdm_cfg.cp_len ...
                        : frame_start + (p0+1)*ofdm_cfg.sym_len - 1);
        Yp = fft(p_body, ofdm_cfg.N_fft) / sqrt(ofdm_cfg.N_fft);
        H_true_p0 = [Yp(ofdm_cfg.idx_data1); Yp(ofdm_cfg.idx_data2)] ./ ofdm_cfg.pilot_syms(:);

        mse_mag = mean((abs(H_data(:,1)) - abs(H_true_p0)).^2);
        corr_mat = corrcoef(abs(H_data(:,1)), abs(H_true_p0));
        fprintf('|H_data| vs |H_true|: corr=%.4f  MSE_mag=%.4f\n', corr_mat(1,2), mse_mag);

        % --- SISO OFDM Demod + MMSE Equalization ---
        n_data_syms = ofdm_cfg.n_data_syms;
        sigma2_eq = rx_power * 10^(-snr_db / 10);
        data_pos = ofdm_cfg.data_sym_pos;

        Y_all = cell(n_data_syms, 1);
        X_all = cell(n_data_syms, 1);
        n_valid = 0;

        for s = 1:n_data_syms
            sym_start = frame_start + data_pos(s) * ofdm_cfg.sym_len;
            if sym_start + ofdm_cfg.sym_len - 1 > length(rx_sync), break; end
            rx_sym = rx_sync(sym_start : sym_start + ofdm_cfg.sym_len - 1);
            Y = ofdm_rx_demod(rx_sym, ofdm_cfg);
            X = channel_equalize(Y, H_data(:, s), 'MMSE', sigma2_eq);
            Y_all{s} = Y;
            X_all{s} = X;
            n_valid = s;
        end

        Y_cat = [];  X_cat = [];
        for s = 1:n_valid
            Y_cat = [Y_cat; Y_all{s}];
            X_cat = [X_cat; X_all{s}];
        end
        total_syms = ceil(length(int_bits) / bpsym);
        Y_cat = Y_cat(1:total_syms);
        X_cat = X_cat(1:total_syms);

        fprintf('Demodulated %d OFDM symbols → %d complex symbols\n', n_valid, length(X_cat));

        rx_syms = X_cat;  % unified variable name for decode chain
        rx_syms_pre_eq = Y_cat;  % for visualization

    else
        % --- MIMO Sync ---
        [rx1_sync, rx2_sync, frame_start, freq_offset] = ofdm_mimo_sync(rx1, rx2, cfg);
        fprintf('Estimated CFO: %.2f Hz\n', freq_offset);

        % --- MIMO Channel Estimation ---
        H_data = mimo_channel_est(rx1_sync, rx2_sync, cfg, frame_start);

        % --- Alamouti Decode ---
        n_pairs = cfg.n_data_pairs;
        n_data_syms = cfg.n_data_syms;
        data_pos = cfg.data_sym_pos;

        X_hat_all = [];
        for p = 1:n_pairs
            d1 = 2*p - 1;  d2 = 2*p;
            sym1 = frame_start + data_pos(d1) * cfg.sym_len;
            sym2 = frame_start + data_pos(d2) * cfg.sym_len;

            Y1_t1 = ofdm_rx_demod(rx1_sync(sym1 : sym1 + cfg.sym_len - 1), cfg);
            Y1_t2 = ofdm_rx_demod(rx1_sync(sym2 : sym2 + cfg.sym_len - 1), cfg);
            Y2_t1 = ofdm_rx_demod(rx2_sync(sym1 : sym1 + cfg.sym_len - 1), cfg);
            Y2_t2 = ofdm_rx_demod(rx2_sync(sym2 : sym2 + cfg.sym_len - 1), cfg);

            H_pair = H_data(d1);
            [s1_hat, s2_hat] = alamouti_decode(Y1_t1, Y1_t2, Y2_t1, Y2_t2, H_pair);
            X_hat_all = [X_hat_all; s1_hat; s2_hat];
        end

        total_syms = ceil(length(int_bits) / bpsym);
        X_hat_all = X_hat_all(1:total_syms);
        fprintf('Alamouti decoded: %d complex symbols\n', length(X_hat_all));

        rx_syms = X_hat_all;  % unified variable name

        % Pre-FEC diagnostic
        rx_test = demodulate(rx_syms, mod_type, 'hard');
        n_test = min(length(rx_test), length(int_bits));
        sym_err = sum(rx_test(1:n_test) ~= int_bits(1:n_test));
        fprintf('Pre-FEC hard errors: %d / %d (%.2e)\n', sym_err, n_test, sym_err/n_test);
    end

    % ========================================================================
    % 6. Common RX Decode: Demod → Deinterleave → Viterbi → CRC
    % ========================================================================
    fprintf('\n===== Decode Chain =====\n');

    % Soft LLR demodulation
    llr_soft = demodulate(rx_syms, mod_type, 'soft');
    rx_bits_hard = demodulate(rx_syms, mod_type, 'hard');

    fprintf('Soft LLR range: [%.2f, %.2f]  mean abs: %.2f\n', ...
            min(llr_soft), max(llr_soft), mean(abs(llr_soft)));

    % Truncate to coded_bits length before deinterleave
    % (ceil rounding in symbol count can add extra bits, e.g. 64QAM: bpsym=6)
    n_coded_orig = length(coded_bits);
    llr_soft      = llr_soft(1:n_coded_orig);
    rx_bits_hard  = rx_bits_hard(1:n_coded_orig);

    % Deinterleave
    llr_deint     = deinterleave(llr_soft, perm);
    rx_hard_deint = deinterleave(rx_bits_hard, perm);

    % Soft vs Hard sign agreement
    soft_sign = double(llr_deint > 0);
    hard_val  = double(rx_hard_deint == 0);
    sign_match = (soft_sign == hard_val);
    fprintf('Soft vs Hard sign agreement: %d / %d (%.1f%%)\n', ...
            sum(sign_match), length(sign_match), sum(sign_match)/length(sign_match)*100);

    % Viterbi decode
    rx_soft_dec = channel_decode(llr_deint, 'soft');
    rx_hard_dec = channel_decode(rx_hard_deint, 'hard');

    % CRC + BER/FER
    [frame_ok_soft, ber_soft, fer_soft] = crc16_check(rx_soft_dec, bits, frame_len);
    [frame_ok_hard, ber_hard, fer_hard] = crc16_check(rx_hard_dec, bits, frame_len);

    % ========================================================================
    % 7. Results Summary
    % ========================================================================
    fprintf('\n===== %s Results =====\n', upper(antenna_scheme));
    fprintf('SNR: %d dB  |  Modulation: %s  |  Antenna: %s\n', snr_db, mod_type, antenna_scheme);
    fprintf('Soft LLR:  BER=%.2e  FER=%.3f  CRC OK=%d/%d\n', ...
            ber_soft, fer_soft, sum(frame_ok_soft), length(frame_ok_soft));
    fprintf('Hard bits: BER=%.2e  FER=%.3f  CRC OK=%d/%d\n', ...
            ber_hard, fer_hard, sum(frame_ok_hard), length(frame_ok_hard));

    % ========================================================================
    % 8. Visualizations
    % ========================================================================
    fprintf('\n===== Generating Visualizations =====\n');

    if is_siso
        % ===== SISO Figure 1: Bit Pipeline =====
        figure(1); clf;
        subplot(5,1,1);
        stem(1:frame_len, bits(1:frame_len), 'b', 'Marker', 'none', 'LineWidth', 0.5);
        ylim([-0.1 1.1]);  xlabel('Bit index');  ylabel('Value');
        title(sprintf('1. Source Bits (1 frame = %d bits)', frame_len));  grid on;

        subplot(5,1,2);  hold on;
        stem(1:frame_len, tx_bits(1:frame_len), 'b', 'Marker', 'none', 'LineWidth', 0.5);
        stem(frame_len+1 : frame_len+crc_len, tx_bits(frame_len+1 : frame_len+crc_len), ...
             'r', 'Marker', 'none', 'LineWidth', 1);
        xline(frame_len + 0.5, 'k--');
        ylim([-0.2 1.2]);  xlabel('Bit index');  ylabel('Value');
        title(sprintf('2. Data + CRC-16 (%d + %d bits)', frame_len, crc_len));
        legend('Data', 'CRC', 'Location', 'best');  grid on;  hold off;

        frame1_coded = coded_bits(1 : 2 * (frame_len + crc_len));
        N_coded = length(frame1_coded);
        burst_start = 300;  burst_end = 700;
        subplot(5,1,3);  hold on;
        stem(1:burst_start-1, frame1_coded(1:burst_start-1), 'g', 'Marker', 'none', 'LineWidth', 0.5);
        stem(burst_start:burst_end, frame1_coded(burst_start:burst_end), 'r', 'Marker', 'none', 'LineWidth', 1);
        stem(burst_end+1:N_coded, frame1_coded(burst_end+1:N_coded), 'g', 'Marker', 'none', 'LineWidth', 0.5);
        ylim([-0.2 1.2]);  xlabel('Bit index');  ylabel('Value');
        title(sprintf('3. Conv Coded R=1/2 (%d bits, red = marked burst)', N_coded));
        legend('Normal', 'Burst', 'Location', 'best');  grid on;  hold off;

        frame1_int = int_bits(1:N_coded);
        burst_in_int = find(ismember(perm(1:N_coded), burst_start:burst_end));
        subplot(5,1,4);  hold on;
        normal_idx = setdiff(1:N_coded, burst_in_int);
        stem(normal_idx, frame1_int(normal_idx), 'g', 'Marker', 'none', 'LineWidth', 0.5);
        stem(burst_in_int, frame1_int(burst_in_int), 'r', 'Marker', 'none', 'LineWidth', 1);
        ylim([-0.1 1.1]);  xlabel('Bit index');  ylabel('Value');
        title(sprintf('4. After Interleaving — burst scattered across %d positions', length(burst_in_int)));
        legend('Normal', 'Burst (scattered)', 'Location', 'best');  grid on;  hold off;

        restored = deinterleave(int_bits, perm);
        frame1_restored = restored(1:N_coded);
        subplot(5,1,5);  hold on;
        stem(1:burst_start-1, frame1_restored(1:burst_start-1), 'g', 'Marker', 'none', 'LineWidth', 0.5);
        stem(burst_start:burst_end, frame1_restored(burst_start:burst_end), 'r', 'Marker', 'none', 'LineWidth', 1);
        stem(burst_end+1:N_coded, frame1_restored(burst_end+1:N_coded), 'g', 'Marker', 'none', 'LineWidth', 0.5);
        ylim([-0.2 1.2]);  xlabel('Bit index');  ylabel('Value');
        title(sprintf('5. After Deinterleaving — burst restored (%d bits)', burst_end - burst_start + 1));
        legend('Normal', 'Burst (restored)', 'Location', 'best');  grid on;  hold off;

        % ===== SISO Figure 2: PDP + Signal Envelope =====
        figure(2); clf;
        subplot(2,1,1);
        stem(chan.delays_us, 10.^(chan.powers_db/10), 'b', 'LineWidth', 2, 'MarkerSize', 8);
        xlabel('Delay (\mus)');  ylabel('Relative Power (linear)');
        title('Power Delay Profile (5-path VHF)');  grid on;

        subplot(2,1,2);
        up = 10;
        N_show = min(2000, min(length(tx_frame), length(rx_signal)));
        t_orig = (1 : N_show)';
        t_fine = (1 : 1/up : N_show)';
        tx_env = abs(tx_frame(1:N_show));
        rx_env = abs(rx_signal(1:N_show));
        tx_smooth = interp1(t_orig, tx_env, t_fine, 'spline');
        rx_smooth = interp1(t_orig, rx_env, t_fine, 'spline');
        plot(t_fine, tx_smooth, 'b-', 'LineWidth', 0.5); hold on;
        plot(t_fine, rx_smooth, 'r-', 'LineWidth', 0.8);
        xlabel(sprintf('Sample (1/%d us)', up));  ylabel('Amplitude');
        title(sprintf('Signal Envelope: TX (blue) vs RX + AWGN (red), SNR=%d dB', snr_db));
        legend('TX', 'RX', 'Location', 'best');  grid on;  hold off;

        % ===== SISO Figure 3: QPSK I/Q Stem =====
        figure(3); clf;
        subplot(2,1,1);
        stem(1:200, real(tx_symbols(1:200)), 'b', 'Marker', 'none', 'LineWidth', 0.5);
        ylim([-1.2 1.2]);  xlabel('Symbol index');  ylabel('I');
        title(sprintf('%s Symbols — In-phase (first 200)', mod_type));  grid on;
        subplot(2,1,2);
        stem(1:200, imag(tx_symbols(1:200)), 'r', 'Marker', 'none', 'LineWidth', 0.5);
        ylim([-1.2 1.2]);  xlabel('Symbol index');  ylabel('Q');
        title(sprintf('%s Symbols — Quadrature (first 200)', mod_type));  grid on;

        % ===== SISO Figure 4: OFDM Time Domain + Freq Domain =====
        figure(4); clf;
        up = 10;
        train_sym_td = tx_frame(1 : expected_sym_len);
        t_fine = (1 : 1/up : expected_sym_len)';
        td_fine = interp1(1:expected_sym_len, real(train_sym_td), t_fine, 'spline');
        cp_end_idx = ofdm_cfg.cp_len * up;
        subplot(2,1,1);  hold on;
        plot(t_fine(1:cp_end_idx), td_fine(1:cp_end_idx), 'r-', 'LineWidth', 1.2);
        plot(t_fine(cp_end_idx+1:end), td_fine(cp_end_idx+1:end), 'b-', 'LineWidth', 0.8);
        xline(ofdm_cfg.cp_len + 0.5, 'k--');
        ylim([-0.3 0.3]);  xlabel('Sample');  ylabel('Amplitude');
        title(sprintf('OFDM Time Domain — CP(%d) + IFFT Body(%d)', ofdm_cfg.cp_len, ofdm_cfg.N_fft));
        legend('CP', 'IFFT Body', 'Location', 'best');  grid on;  hold off;

        freq_data = zeros(ofdm_cfg.N_fft, 1);
        freq_data(ofdm_cfg.idx_data1) = ofdm_cfg.train_syms(1 : ofdm_cfg.half_active);
        freq_data(ofdm_cfg.idx_data2) = ofdm_cfg.train_syms(ofdm_cfg.half_active + 1 : end);
        subplot(2,1,2);
        stem(1:ofdm_cfg.N_fft, real(freq_data), 'b', 'Marker', 'none', 'LineWidth', 1);
        ylim([-1.2 1.2]);  xlabel('FFT Bin');  ylabel('Symbol Value');
        title(sprintf('Training Symbol — Freq Domain (%d active BPSK subcarriers)', ofdm_cfg.N_active));
        grid on;

        % ===== SISO Figure 5: Time Sync + Phase Drift =====
        figure(5); clf;
        train_ref = ofdm_cfg.train_tx;
        [corr, lag] = xcorr(rx_signal, train_ref);
        subplot(3,1,1);
        plot(lag, abs(corr), 'b-', 'LineWidth', 0.8);
        hold on;  xline(frame_start, 'r--', 'LineWidth', 2);  hold off;
        xlabel('Lag (samples)');  ylabel('|Correlation|');
        title('Time Sync — Cross-correlation with Training Symbol');
        legend('|Corr|', 'Detected peak', 'Location', 'best');  grid on;

        k_sc = 200;
        pilot_pos = ofdm_cfg.pilot_positions;
        n_pilots = length(pilot_pos);
        t_ms = zeros(1, n_pilots);
        ph_bf = zeros(1, n_pilots);
        ph_af = zeros(1, n_pilots);
        for i = 1:n_pilots
            p_sym = pilot_pos(i);
            t_ms(i) = p_sym * ofdm_cfg.sym_len / 1e6 * 1000;
            p_body_bf = rx_signal(frame_start + p_sym*ofdm_cfg.sym_len + ofdm_cfg.cp_len ...
                        : frame_start + (p_sym+1)*ofdm_cfg.sym_len - 1);
            Y_bf = fft(p_body_bf, ofdm_cfg.N_fft) / sqrt(ofdm_cfg.N_fft);
            Y_bf_act = [Y_bf(ofdm_cfg.idx_data1); Y_bf(ofdm_cfg.idx_data2)];
            ph_bf(i) = angle(Y_bf_act(k_sc) / ofdm_cfg.pilot_syms(k_sc));
            p_body_af = rx_sync(frame_start + p_sym*ofdm_cfg.sym_len + ofdm_cfg.cp_len ...
                        : frame_start + (p_sym+1)*ofdm_cfg.sym_len - 1);
            Y_af = fft(p_body_af, ofdm_cfg.N_fft) / sqrt(ofdm_cfg.N_fft);
            Y_af_act = [Y_af(ofdm_cfg.idx_data1); Y_af(ofdm_cfg.idx_data2)];
            ph_af(i) = angle(Y_af_act(k_sc) / ofdm_cfg.pilot_syms(k_sc));
        end
        ph_bf = unwrap(ph_bf) * 180 / pi;
        ph_af = unwrap(ph_af) * 180 / pi;

        subplot(3,1,2);
        plot(t_ms, ph_bf, 'ro-', 'LineWidth', 1.5, 'MarkerSize', 8); hold on;
        expected_ph = 360 * cfo_hz * t_ms * 1e-3;
        expected_ph = expected_ph - expected_ph(1) + ph_bf(1);
        plot(t_ms, expected_ph, 'b--', 'LineWidth', 1.0); hold off;
        xlabel('Time (ms)');  ylabel('Phase (deg)');
        title(sprintf('Pilot Subc %d Phase BEFORE Correction', k_sc));
        legend('Measured', sprintf('Expected %.0f Hz', cfo_hz), 'Location', 'best'); grid on;

        subplot(3,1,3);
        plot(t_ms, ph_af, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 8);
        yline(0, 'k--');
        xlabel('Time (ms)');  ylabel('Phase (deg)');
        title(sprintf('Pilot Subc %d Phase AFTER Correction (mean=%.2f deg)', k_sc, mean(ph_af)));
        grid on;

        % ===== SISO Figure 6: Channel Estimation =====
        figure(6); clf;
        subplot(2,1,1);
        plot(1:ofdm_cfg.N_active, 20*log10(abs(H_true_p0)), 'b-', 'LineWidth', 1.2); hold on;
        plot(1:ofdm_cfg.N_active, 20*log10(abs(H_data(:,1))), 'r--', 'LineWidth', 1.0);
        xlabel('Subcarrier Index');  ylabel('|H| (dB)');
        title(sprintf('Channel Magnitude: True vs Est (SNR=%d dB, corr=%.4f)', snr_db, corr_mat(1,2)));
        legend('True |H|', 'Est |H|', 'Location', 'best');  grid on;  hold off;
        subplot(2,1,2);
        plot(1:ofdm_cfg.N_active, angle(H_true_p0)*180/pi, 'b-', 'LineWidth', 1.2); hold on;
        plot(1:ofdm_cfg.N_active, angle(H_data(:,1))*180/pi, 'r--', 'LineWidth', 1.0);
        xlabel('Subcarrier Index');  ylabel('Phase (deg)');
        title('Channel Phase: True vs Est');
        legend('True Phase', 'Est Phase', 'Location', 'best');  grid on;  hold off;

        % ===== SISO Figure 7: Constellation (Before EQ, After EQ, vs Ideal) =====
        N_plot = min(2000, length(rx_syms_pre_eq));
        figure(7); clf;
        subplot(1,3,1);
        plot(real(rx_syms_pre_eq(1:N_plot)), imag(rx_syms_pre_eq(1:N_plot)), 'r.', 'MarkerSize', 5);
        xlabel('I');  ylabel('Q');
        title(sprintf('RX Before EQ (%d symbols)', N_plot));
        axis equal;  grid on;
        subplot(1,3,2);
        plot(real(rx_syms(1:N_plot)), imag(rx_syms(1:N_plot)), 'b.', 'MarkerSize', 5);
        xlabel('I');  ylabel('Q');
        title(sprintf('After MMSE EQ (%d symbols)', N_plot));
        axis equal;  grid on;
        subplot(1,3,3);
        M = 4;  if strcmp(mod_type,'16QAM'), M=16; elseif strcmp(mod_type,'64QAM'), M=64; end
        ref_syms = qammod(0:M-1, M, 'UnitAveragePower', true);
        plot(real(ref_syms), imag(ref_syms), 'ko', 'MarkerSize', 12, 'LineWidth', 2); hold on;
        plot(real(rx_syms(1:N_plot)), imag(rx_syms(1:N_plot)), 'b.', 'MarkerSize', 3);
        xlabel('I');  ylabel('Q');
        title(sprintf('MMSE EQ vs Ideal %s (SNR=%d dB)', mod_type, snr_db));
        legend(sprintf('Ideal %s', mod_type), 'EQ output', 'Location', 'best');
        axis equal;  grid on;  hold off;

        % ===== SISO Figure 8: BER/FER Bar Chart =====
        figure(8); clf;
        all_zero = (ber_soft==0 && fer_soft==0 && ber_hard==0 && fer_hard==0);
        if all_zero
            bar_data = [ber_soft, fer_soft; ber_hard, fer_hard]';
            b = bar(bar_data, 'grouped');
        else
            min_visible = 1e-9;
            bar_data = [max(ber_soft,min_visible), max(fer_soft,min_visible); ...
                        max(ber_hard,min_visible), max(fer_hard,min_visible)]';
            b = bar(bar_data, 'grouped');
            set(gca, 'YScale', 'log');
        end
        b(1).FaceColor = [0.23 0.51 0.92];
        b(2).FaceColor = [0.85 0.33 0.10];
        set(gca, 'XTickLabel', {'BER', 'FER'});
        ylabel('Error Rate');
        title(sprintf('BER/FER: Soft vs Hard Decision (%s, SNR=%d dB, SISO)', mod_type, snr_db));
        legend('Soft LLR', 'Hard', 'Location', 'northwest');
        real_vals = {ber_soft, fer_soft; ber_hard, fer_hard};
        for i = 1:2
            for j = 1:2
                v = real_vals{j, i};
                lbl = ternary(v==0, '0', sprintf('%.2e', v));
                text(b(j).XEndPoints(i), b(j).YEndPoints(i), lbl, ...
                     'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
            end
        end
        grid on;

    else
        % ===== MIMO Figure 1: Alamouti Constellation =====
        N_plot = min(2000, length(rx_syms));
        figure(1); clf;
        subplot(1,2,1);
        plot(real(rx_syms(1:N_plot)), imag(rx_syms(1:N_plot)), 'b.', 'MarkerSize', 5);
        xlabel('I');  ylabel('Q');
        title(sprintf('Alamouti 2×2 Output (%d symbols, SNR=%d dB)', N_plot, snr_db));
        axis equal;  grid on;
        subplot(1,2,2);
        M = 4;  if strcmp(mod_type,'16QAM'), M=16; elseif strcmp(mod_type,'64QAM'), M=64; end
        ref_syms = qammod(0:M-1, M, 'UnitAveragePower', true);
        plot(real(ref_syms), imag(ref_syms), 'ko', 'MarkerSize', 12, 'LineWidth', 2); hold on;
        plot(real(rx_syms(1:N_plot)), imag(rx_syms(1:N_plot)), 'b.', 'MarkerSize', 3);
        xlabel('I');  ylabel('Q');  title(sprintf('Alamouti vs Ideal %s', mod_type));
        legend(sprintf('Ideal %s', mod_type), 'Alamouti out', 'Location', 'best');
        axis equal;  grid on;  hold off;

        % ===== MIMO Figure 2: MIMO 4-Channel True vs Estimated =====
        cp_len = cfg.cp_len;  N_fft = cfg.N_fft;  sym_len = cfg.sym_len;
        pg0 = cfg.pilot_group_pos(1);
        p1s = frame_start + pg0 * sym_len + cp_len;  p1e = p1s + N_fft - 1;
        Yc1_1 = fft(rx1_clean(p1s:p1e), N_fft) / sqrt(N_fft);
        Yc2_1 = fft(rx2_clean(p1s:p1e), N_fft) / sqrt(N_fft);
        Ht_h11 = [Yc1_1(cfg.idx_data1); Yc1_1(cfg.idx_data2)] ./ cfg.pilot_syms_1(:);
        Ht_h21 = [Yc2_1(cfg.idx_data1); Yc2_1(cfg.idx_data2)] ./ cfg.pilot_syms_1(:);
        p2s = frame_start + (pg0+1) * sym_len + cp_len;  p2e = p2s + N_fft - 1;
        Yc1_2 = fft(rx1_clean(p2s:p2e), N_fft) / sqrt(N_fft);
        Yc2_2 = fft(rx2_clean(p2s:p2e), N_fft) / sqrt(N_fft);
        Ht_h12 = [Yc1_2(cfg.idx_data1); Yc1_2(cfg.idx_data2)] ./ cfg.pilot_syms_2(:);
        Ht_h22 = [Yc2_2(cfg.idx_data1); Yc2_2(cfg.idx_data2)] ./ cfg.pilot_syms_2(:);

        figure(2); clf;
        true_ch = {Ht_h11, Ht_h12, Ht_h21, Ht_h22};
        est_ch  = {H_data(1).h11, H_data(1).h12, H_data(1).h21, H_data(1).h22};
        names   = {'TX1→RX1', 'TX1→RX2', 'TX2→RX1', 'TX2→RX2'};
        for col = 1:4
            subplot(2,2,col);
            plot(1:cfg.N_active, 20*log10(abs(true_ch{col})), 'b-', 'LineWidth', 1.0); hold on;
            plot(1:cfg.N_active, 20*log10(abs(est_ch{col})),  'r--', 'LineWidth', 0.8);
            xlabel('Subc');  ylabel('|H| (dB)');
            title(names{col});
            legend('True', 'Est', 'Location', 'best');  grid on;
            hold off;
        end
        sgtitle(sprintf('MIMO 2×2 Channel: True vs Est at 1st Data Sym (SNR=%d dB)', snr_db));

        % ===== MIMO Figure 3: BER/FER Bar Chart =====
        figure(3); clf;
        all_zero = (ber_soft==0 && fer_soft==0);
        if all_zero
            b = bar([ber_soft, fer_soft], 'FaceColor', [0.23 0.51 0.92]);
        else
            min_visible = 1e-9;
            b = bar([max(ber_soft,min_visible), max(fer_soft,min_visible)], ...
                    'FaceColor', [0.23 0.51 0.92]);
            set(gca, 'YScale', 'log');
        end
        set(gca, 'XTickLabel', {'BER', 'FER'});
        ylabel('Error Rate');
        title(sprintf('MIMO 2×2 Alamouti — BER/FER (SNR=%d dB, %s)', snr_db, mod_type));
        ber_label = ternary(ber_soft==0, '0', sprintf('%.2e', ber_soft));
        fer_label = ternary(fer_soft==0, '0', sprintf('%.2e', fer_soft));
        text(b.XEndPoints(1), b.YEndPoints(1), ber_label, ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
        text(b.XEndPoints(2), b.YEndPoints(2), fer_label, ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
        grid on;

        % ===== MIMO Figure 4: Bit Pipeline =====
        figure(4); clf;
        frame1_data = bits(1:min(frame_len, N));
        subplot(5,1,1);
        stem(1:frame_len, [frame1_data zeros(1,frame_len-length(frame1_data))], 'b', 'Marker','none','LineWidth',0.5);
        ylim([-0.1 1.1]); xlabel('Bit index'); ylabel('Value');
        title(sprintf('1. Source Bits (1 frame = %d bits)', frame_len)); grid on;
        subplot(5,1,2); hold on;
        stem(1:frame_len, tx_bits(1:frame_len), 'b', 'Marker','none','LineWidth',0.5);
        stem(frame_len+1:frame_len+crc_len, tx_bits(frame_len+1:frame_len+crc_len), 'r', 'Marker','none','LineWidth',1);
        xline(frame_len+0.5, 'k--');
        ylim([-0.2 1.2]); xlabel('Bit index'); ylabel('Value');
        title(sprintf('2. Data + CRC-16 (%d + %d bits)', frame_len, crc_len));
        legend('Data','CRC','Location','best'); grid on; hold off;
        frame1_coded = coded_bits(1:2*(frame_len+crc_len));
        Nc = length(frame1_coded);
        burst_start = 300;  burst_end = 700;
        subplot(5,1,3); hold on;
        stem(1:burst_start-1, frame1_coded(1:burst_start-1), 'g', 'Marker','none','LineWidth',0.5);
        stem(burst_start:burst_end, frame1_coded(burst_start:burst_end), 'r', 'Marker','none','LineWidth',1);
        stem(burst_end+1:Nc, frame1_coded(burst_end+1:Nc), 'g', 'Marker','none','LineWidth',0.5);
        ylim([-0.2 1.2]); xlabel('Bit index'); ylabel('Value');
        title(sprintf('3. Conv Coded R=1/2 (%d bits, red = marked burst)', Nc));
        legend('Normal','Burst','Location','best'); grid on; hold off;

        frame1_int = int_bits(1:Nc);
        burst_in_int = find(ismember(perm(1:Nc), burst_start:burst_end));
        subplot(5,1,4); hold on;
        normal_idx = setdiff(1:Nc, burst_in_int);
        stem(normal_idx, frame1_int(normal_idx), 'g', 'Marker','none','LineWidth',0.5);
        stem(burst_in_int, frame1_int(burst_in_int), 'r', 'Marker','none','LineWidth',1);
        ylim([-0.1 1.1]); xlabel('Bit index'); ylabel('Value');
        title(sprintf('4. After Interleaving — burst scattered across %d positions', length(burst_in_int)));
        legend('Normal','Burst (scattered)','Location','best'); grid on; hold off;

        all_restored = deinterleave(int_bits, perm);
        restored = all_restored(1:Nc);
        subplot(5,1,5); hold on;
        stem(1:burst_start-1, restored(1:burst_start-1), 'g', 'Marker','none','LineWidth',0.5);
        stem(burst_start:burst_end, restored(burst_start:burst_end), 'r', 'Marker','none','LineWidth',1);
        stem(burst_end+1:Nc, restored(burst_end+1:Nc), 'g', 'Marker','none','LineWidth',0.5);
        ylim([-0.2 1.2]); xlabel('Bit index'); ylabel('Value');
        title(sprintf('5. After Deinterleaving — burst restored (%d bits)', burst_end-burst_start+1));
        legend('Normal','Burst (restored)','Location','best'); grid on; hold off;
        sgtitle('MIMO 2×2 — Bit Pipeline');

        % ===== MIMO Figure 5: PDP + Noisy Frequency Response =====
        figure(5); clf;
        delays_us = [0, 0.2, 0.5, 1.0, 2.0];
        powers_db = [0, -3, -6, -9, -12];
        subplot(2,1,1);
        stem(delays_us, 10.^(powers_db/10), 'b', 'LineWidth', 2, 'MarkerSize', 8);
        xlabel('Delay (\mus)'); ylabel('Relative Power');
        title('Power Delay Profile (5-path VHF)'); grid on;
        subplot(2,1,2);
        plot(1:cfg.N_active, 20*log10(abs(H_data(1).h11)), 'b-', 'LineWidth', 0.8);
        xlabel('Subcarrier Index'); ylabel('|H| (dB)');
        title(sprintf('Noisy Channel Freq Response — TX1→RX1 (SNR=%d dB)', snr_db));
        grid on;
        sgtitle('MIMO 2×2 — Channel');

        % ===== MIMO Figure 6: OFDM Time Domain + Freq Domain =====
        figure(6); clf;
        up = 10;
        train_sym_td = tx1(1 : expected_sym_len);
        t_fine = (1 : 1/up : expected_sym_len)';
        td_fine = interp1(1:expected_sym_len, real(train_sym_td), t_fine, 'spline');
        cp_end_idx = cfg.cp_len * up;
        subplot(2,1,1); hold on;
        plot(t_fine(1:cp_end_idx), td_fine(1:cp_end_idx), 'r-', 'LineWidth', 1.2);
        plot(t_fine(cp_end_idx+1:end), td_fine(cp_end_idx+1:end), 'b-', 'LineWidth', 0.8);
        xline(cfg.cp_len + 0.5, 'k--');
        ylim([-0.3 0.3]); xlabel('Sample'); ylabel('Amplitude');
        title(sprintf('TX1 Training — CP(%d) + IFFT Body(%d)', cfg.cp_len, cfg.N_fft));
        legend('CP','IFFT Body','Location','best'); grid on; hold off;
        freq_data = zeros(cfg.N_fft, 1);
        freq_data(cfg.idx_data1) = cfg.train_syms_1(1:cfg.half_active);
        freq_data(cfg.idx_data2) = cfg.train_syms_1(cfg.half_active+1:end);
        subplot(2,1,2);
        stem(1:cfg.N_fft, real(freq_data), 'b', 'Marker','none','LineWidth', 1);
        ylim([-1.2 1.2]); xlabel('FFT Bin'); ylabel('Symbol Value');
        title(sprintf('TX1 Training — Freq Domain (%d active BPSK)', cfg.N_active));
        grid on;
        sgtitle('MIMO 2×2 — OFDM Modulation');

        % ===== MIMO Figure 7: Sync (RX1+RX2 Correlation + Phase Drift) =====
        figure(7); clf;
        [corr1, lag1] = xcorr(rx1, cfg.train_tx_1);
        [corr2, lag2] = xcorr(rx2, cfg.train_tx_1);
        subplot(3,1,1);
        plot(lag1, abs(corr1), 'b-', 'LineWidth', 0.8); hold on;
        plot(lag2, abs(corr2), 'r-', 'LineWidth', 0.8);
        xline(frame_start, 'k--', 'LineWidth', 1.5); hold off;
        xlabel('Lag (samples)'); ylabel('|Correlation|');
        title(sprintf('Time Sync — RX1 & RX2 vs TX1 Training (peak@%d)', frame_start));
        legend('RX1', 'RX2', 'Location', 'best'); grid on;

        k_sc = 200;
        pg_pos = cfg.pilot_group_pos;
        n_pg = length(pg_pos);
        t_ms = zeros(1, n_pg);
        ph_bf = zeros(1, n_pg);
        ph_af = zeros(1, n_pg);
        for i = 1:n_pg
            p_sym_m = pg_pos(i);
            t_ms(i) = p_sym_m * cfg.sym_len / 1e6 * 1000;
            p_body_bf = rx1(frame_start + p_sym_m*cfg.sym_len + cfg.cp_len ...
                      : frame_start + (p_sym_m+1)*cfg.sym_len - 1);
            Y_bf = fft(p_body_bf, cfg.N_fft) / sqrt(cfg.N_fft);
            Y_bf_act = [Y_bf(cfg.idx_data1); Y_bf(cfg.idx_data2)];
            ph_bf(i) = angle(Y_bf_act(k_sc) / cfg.pilot_syms_1(k_sc));
            p_body_af = rx1_sync(frame_start + p_sym_m*cfg.sym_len + cfg.cp_len ...
                      : frame_start + (p_sym_m+1)*cfg.sym_len - 1);
            Y_af = fft(p_body_af, cfg.N_fft) / sqrt(cfg.N_fft);
            Y_af_act = [Y_af(cfg.idx_data1); Y_af(cfg.idx_data2)];
            ph_af(i) = angle(Y_af_act(k_sc) / cfg.pilot_syms_1(k_sc));
        end
        ph_bf = unwrap(ph_bf) * 180 / pi;
        ph_af = unwrap(ph_af) * 180 / pi;

        subplot(3,1,2);
        plot(t_ms, ph_bf, 'ro-', 'LineWidth', 1.5, 'MarkerSize', 8); hold on;
        expected_ph = 360 * cfo_hz * t_ms * 1e-3;
        expected_ph = expected_ph - expected_ph(1) + ph_bf(1);
        plot(t_ms, expected_ph, 'b--', 'LineWidth', 1.0); hold off;
        xlabel('Time (ms)'); ylabel('Phase (deg)');
        title(sprintf('TX1 Pilot Subc %d Phase BEFORE Correction', k_sc));
        legend('Measured', sprintf('Expected %.0f Hz', cfo_hz), 'Location', 'best'); grid on;

        subplot(3,1,3);
        plot(t_ms, ph_af, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 8);
        yline(0, 'k--');
        xlabel('Time (ms)'); ylabel('Phase (deg)');
        title(sprintf('TX1 Pilot Subc %d Phase AFTER Correction (mean=%.2f deg)', k_sc, mean(ph_af)));
        grid on;
    end

    fprintf('\n===== Simulation Complete =====\n');
end

% ==========================================================================
% Local Function: Auto-select modulation based on SNR and antenna scheme
% ==========================================================================
function mod_type = auto_select_modulation(snr_db, antenna_scheme)
% SISO thresholds:  QPSK < 10 dB ≤ 16QAM < 20 dB ≤ 64QAM
% MIMO thresholds:  QPSK <  7 dB ≤ 16QAM < 17 dB ≤ 64QAM  (diversity gain ~3 dB)

    if strcmpi(antenna_scheme, 'mimo')
        if snr_db < 7
            mod_type = 'QPSK';
        elseif snr_db < 17
            mod_type = '16QAM';
        else
            mod_type = '64QAM';
        end
    else
        if snr_db < 12
            mod_type = 'QPSK';
        elseif snr_db < 22
            mod_type = '16QAM';
        else
            mod_type = '64QAM';
        end
    end
end

% ==========================================================================
% Local helper
% ==========================================================================
function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
