% test_all_mimo.m — 2×2 Alamouti OFDM MIMO test script
% Reuses existing SISO modules where possible.
% Usage: run test_all_mimo
close all;
clear; clc;

%% ===== Global Parameters =====
N = 1000000;              % Total source bits
frame_len = 1024;       % Data bits per frame (CRC unit)
crc_len = 16;
mod_type = 'QPSK';
cfo_hz = 10;            % CFO injection
snr_db = 5;             % AWGN SNR

% GUI parameter override (from vhf_ofdm_app)
if exist('gui_params.mat', 'file')
    p = load('gui_params.mat');
    if isfield(p, 'snr_val'), snr_db = p.snr_val; end
    if isfield(p, 'N'), N = p.N; end
    delete('gui_params.mat');
end

fprintf('===== MIMO 2x2 Alamouti OFDM Test =====\n');
fprintf('Source: %d bits  |  Frame: %d data + %d CRC\n', N, frame_len, crc_len); fprintf('Mod: %s  |  CFO: %.1f Hz  |  SNR: %d dB\n', mod_type, cfo_hz, snr_db);  %% ===== 1. TX Chain: Source → CRC → Encode → Interleave → Modulate ===== fprintf('\n--- TX Chain ---\n');
bits = generate_source(N);
tx_bits = crc16_encode(bits, frame_len);
coded_bits = channel_encode(tx_bits);
[int_bits, perm] = interleave(coded_bits);

fprintf('Source: %d → CRC: %d → Coded: %d bits\n', N, length(tx_bits), length(coded_bits));  %% ===== 2. MIMO OFDM Frame Assembly ===== fprintf('\n--- MIMO OFDM Frame ---\n');
pilot_spacing = 40;  % data symbols between periodic pilot groups
[tx1, tx2, cfg] = mimo_ofdm_assemble_frame(int_bits, mod_type, pilot_spacing);

%% ===== 3. MIMO Channel =====
fprintf('\n--- MIMO 2x2 Channel ---\n');
[rx1, rx2] = mimo_channel(tx1, tx2);

%% ===== 4. CFO + AWGN =====
fprintf('\n--- CFO + AWGN ---\n');
fs = 1e6;
rx_power = (mean(abs(rx1).^2) + mean(abs(rx2).^2)) / 2;

% CFO injection (common to both antennas)
if cfo_hz ~= 0
    t1 = (0 : length(rx1) - 1)' / fs;
    t2 = (0 : length(rx2) - 1)' / fs;
    rx1 = rx1 .* exp(1j * 2 * pi * cfo_hz * t1);
    rx2 = rx2 .* exp(1j * 2 * pi * cfo_hz * t2);
    fprintf('CFO injected: %.1f Hz\n', cfo_hz);
end

% Save noiseless signals for true channel comparison
rx1_clean = rx1;
rx2_clean = rx2;

% AWGN (independent per antenna)
rx1 = add_awgn(rx1, snr_db);
rx2 = add_awgn(rx2, snr_db);
fprintf('AWGN added: SNR = %d dB per antenna\n', snr_db);

%% ===== 5. MIMO Sync =====
fprintf('\n--- MIMO Sync ---\n');
[rx1_sync, rx2_sync, frame_start, freq_offset] = ofdm_mimo_sync(rx1, rx2, cfg);
fprintf('Estimated CFO: %.2f Hz\n', freq_offset);

%% ===== 6. MIMO Channel Estimation =====
fprintf('\n--- MIMO Channel Estimation ---\n');
H_data = mimo_channel_est(rx1_sync, rx2_sync, cfg, frame_start);

%% ===== 7. OFDM Demod + Alamouti Decode =====
fprintf('\n--- Alamouti Decode ---\n');

n_pairs = cfg.n_data_pairs;
n_data_syms = cfg.n_data_syms;
data_pos = cfg.data_sym_pos;  % frame symbol index of each data OFDM symbol
X_hat_all = [];

for p = 1:n_pairs
    d1 = 2*p - 1;  % first data symbol (1-indexed)
    d2 = 2*p;      % second data symbol

    sym1 = frame_start + data_pos(d1) * cfg.sym_len;
    sym2 = frame_start + data_pos(d2) * cfg.sym_len;

    % OFDM demod both slots, both antennas
    Y1_t1 = ofdm_rx_demod(rx1_sync(sym1 : sym1 + cfg.sym_len - 1), cfg);
    Y1_t2 = ofdm_rx_demod(rx1_sync(sym2 : sym2 + cfg.sym_len - 1), cfg);
    Y2_t1 = ofdm_rx_demod(rx2_sync(sym1 : sym1 + cfg.sym_len - 1), cfg);
    Y2_t2 = ofdm_rx_demod(rx2_sync(sym2 : sym2 + cfg.sym_len - 1), cfg);

    % Alamouti combining (use channel at first slot, constant over pair)
    H_pair = H_data(d1);
    [s1_hat, s2_hat] = alamouti_decode(Y1_t1, Y1_t2, Y2_t1, Y2_t2, H_pair);

    X_hat_all = [X_hat_all; s1_hat; s2_hat];
end

% Trim to original data length
bpsym_map = containers.Map({'QPSK','16QAM','64QAM'}, [2, 4, 6]);
bpsym = bpsym_map(upper(mod_type));
total_syms = ceil(length(int_bits) / bpsym);
X_hat_all = X_hat_all(1:total_syms);

fprintf('Alamouti decoded: %d complex symbols\n', length(X_hat_all));  % ---- Diagnostic: check Alamouti output quality ---- fprintf('\n--- Diagnostic ---\n');
% Pre-FEC symbol error check (hard decision on Alamouti output)
rx_test = demodulate(X_hat_all, mod_type, 'hard');
n_test = min(length(rx_test), length(int_bits));
sym_err = sum(rx_test(1:n_test) ~= int_bits(1:n_test));
fprintf('Pre-FEC hard errors: %d / %d (%.2e)  -- if >>0, Alamouti decode broken\n', ...
        sym_err, n_test, sym_err/n_test);

% Check symbol constellation scale
fprintf('|X_hat| stats: mean=%.3f  std=%.3f  (expected ~0.7 for QPSK unit power)\n', ...
        mean(abs(X_hat_all)), std(abs(X_hat_all)));

% Check soft value distribution
llr_tmp = demodulate(X_hat_all, mod_type, 'soft');
soft_sign = double(llr_tmp(1:min(200,end)) > 0);
hard_200 = double(rx_test(1:min(200,end)) == 0);
match_pre = (soft_sign == hard_200);
fprintf('Soft vs Hard sign match (first 200): %d/200 (%.0f%%)  -- should be >90%%\n', ...
        sum(match_pre), sum(match_pre)/min(200,length(match_pre))*100);
fprintf('Soft values: min=%.2f  med=%.2f  max=%.2f  (expected ~±1 for QPSK)\n', ...
        min(llr_tmp), median(llr_tmp), max(llr_tmp));

%% ===== 8. Soft Demod → Deinterleave → Viterbi → CRC =====
fprintf('\n--- RX Decode Chain ---\n');
% Soft demodulation
llr_soft = demodulate(X_hat_all, mod_type, 'soft');
% Hard demod for comparison
rx_bits_hard = demodulate(X_hat_all, mod_type, 'hard');
% Deinterleave both
llr_deint = deinterleave(llr_soft, perm);
rx_hard_deint = deinterleave(rx_bits_hard, perm);
n_coded = length(coded_bits);
llr_deint = llr_deint(1:n_coded);
rx_hard_deint = rx_hard_deint(1:n_coded);

% Viterbi decode
rx_soft_dec = channel_decode(llr_deint, 'soft');
rx_hard_dec = channel_decode(rx_hard_deint, 'hard');
% CRC + BER
[frame_ok_soft, ber_soft, fer_soft] = crc16_check(rx_soft_dec, bits, frame_len);
[frame_ok_hard, ber_hard, fer_hard] = crc16_check(rx_hard_dec, bits, frame_len);

%% ===== 9. Results + Visualizations =====
fprintf('\n===== MIMO 2x2 Alamouti Results =====\n');
fprintf('SNR: %d dB  |  Modulation: %s\n', snr_db, mod_type);
fprintf('Soft LLR:  BER=%.2e  FER=%.3f  CRC OK=%d/%d\n', ...
        ber_soft, fer_soft, sum(frame_ok_soft), length(frame_ok_soft));
fprintf('Hard bits: BER=%.2e  FER=%.3f  CRC OK=%d/%d\n', ...
        ber_hard, fer_hard, sum(frame_ok_hard), length(frame_ok_hard));

% --- Figure 1: Constellation ---
N_plot = min(2000, length(X_hat_all));
figure(1); clf;
subplot(1,2,1);
plot(real(X_hat_all(1:N_plot)), imag(X_hat_all(1:N_plot)), 'b.', 'MarkerSize', 5);
xlabel('I');  ylabel('Q');
title(sprintf('Alamouti 2x2 Output (%d symbols, SNR=%d dB)', N_plot, snr_db));
axis equal;  grid on;
subplot(1,2,2);
ref_syms = [1+1j, 1-1j, -1+1j, -1-1j] / sqrt(2);
plot(real(ref_syms), imag(ref_syms), 'ko', 'MarkerSize', 12, 'LineWidth', 2); hold on;
plot(real(X_hat_all(1:N_plot)), imag(X_hat_all(1:N_plot)), 'b.', 'MarkerSize', 3);
xlabel('I');  ylabel('Q');  title('Alamouti vs Ideal QPSK');
legend('Ideal QPSK', 'Alamouti out', 'Location', 'best');
axis equal;  grid on;  hold off;

% --- True channel from noiseless signal at first pilot group ---
cp_len = cfg.cp_len;  N_fft = cfg.N_fft;  sym_len = cfg.sym_len;
pg0 = cfg.pilot_group_pos(1);
% TX1 pilot (H11, H21)
p1s = frame_start + pg0 * sym_len + cp_len;
p1e = p1s + N_fft - 1;
Yc1_1 = fft(rx1_clean(p1s:p1e), N_fft) / sqrt(N_fft);
Yc2_1 = fft(rx2_clean(p1s:p1e), N_fft) / sqrt(N_fft);
Ht_h11 = [Yc1_1(cfg.idx_data1); Yc1_1(cfg.idx_data2)] ./ cfg.pilot_syms_1(:);
Ht_h21 = [Yc2_1(cfg.idx_data1); Yc2_1(cfg.idx_data2)] ./ cfg.pilot_syms_1(:);
% TX2 pilot (H12, H22)
p2s = frame_start + (pg0+1) * sym_len + cp_len;
p2e = p2s + N_fft - 1;
Yc1_2 = fft(rx1_clean(p2s:p2e), N_fft) / sqrt(N_fft);
Yc2_2 = fft(rx2_clean(p2s:p2e), N_fft) / sqrt(N_fft);
Ht_h12 = [Yc1_2(cfg.idx_data1); Yc1_2(cfg.idx_data2)] ./ cfg.pilot_syms_2(:);
Ht_h22 = [Yc2_2(cfg.idx_data1); Yc2_2(cfg.idx_data2)] ./ cfg.pilot_syms_2(:);

% --- Figure 2: True vs Estimated at first data symbol ---
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
sgtitle(sprintf('MIMO 2x2 Channel: True vs Est at 1st Data Sym (SNR=%d dB)', snr_db));

% --- Figure 3: BER/FER bar chart ---
figure(3); clf;
bar_data = [ber_soft, fer_soft; ber_hard, fer_hard]';
b = bar(bar_data, 'grouped');
b(1).FaceColor = [0.23 0.51 0.92];  % soft blue
b(2).FaceColor = [0.85 0.33 0.10];  % hard red
set(gca, 'XTickLabel', {'BER', 'FER'});
ylabel('Error Rate');
title(sprintf('MIMO 2x2 Alamouti — BER/FER (SNR=%d dB, %s)', snr_db, mod_type));
legend('Soft LLR', 'Hard', 'Location', 'northwest');
for i = 1:2
    text(b(1).XEndPoints(i), b(1).YEndPoints(i), sprintf('%.2e', b(1).YEndPoints(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
    text(b(2).XEndPoints(i), b(2).YEndPoints(i), sprintf('%.2e', b(2).YEndPoints(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
end
grid on;

%% ===== 10. TX Chain Visualization (Bit Pipeline) =====
fprintf('\n--- TX Chain Visualization ---\n');
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
subplot(5,1,3); hold on;
stem(1:Nc/2, frame1_coded(1:Nc/2), 'g', 'Marker','none','LineWidth',0.5);
stem(Nc/2+1:Nc, frame1_coded(Nc/2+1:Nc), 'r', 'Marker','none','LineWidth',1);
ylim([-0.2 1.2]); xlabel('Bit index'); ylabel('Value');
title(sprintf('3. Conv Coded R=1/2 (%d bits)', Nc)); grid on; hold off;

frame1_int = int_bits(1:Nc);
subplot(5,1,4); hold on;
stem(1:2:Nc, frame1_int(1:2:Nc), 'g', 'Marker','none','LineWidth',0.5);
stem(2:2:Nc, frame1_int(2:2:Nc), 'r', 'Marker','none','LineWidth',0.5);
ylim([-0.1 1.1]); xlabel('Bit index'); ylabel('Value');
title('4. After Interleaving'); grid on; hold off;

all_restored = deinterleave(int_bits, perm);
restored = all_restored(1:Nc);
subplot(5,1,5); hold on;
% After deinterleave, bits should match original encoder output order
% Use same red/green split as subplot 3 for comparison
stem(1:Nc/2, restored(1:Nc/2), 'g', 'Marker','none','LineWidth',0.5);
stem(Nc/2+1:Nc, restored(Nc/2+1:Nc), 'r', 'Marker','none','LineWidth',1);
ylim([-0.2 1.2]); xlabel('Bit index'); ylabel('Value');
title('5. After Deinterleaving — should match coded output'); grid on; hold off;

sgtitle('MIMO 2x2 — Bit Pipeline');
%% ===== 11. Channel PDP + Noisy Freq Response =====
fprintf('\n--- Channel Visualization ---\n');
figure(5); clf;

% PDP (same 5-path for all links)
subplot(2,1,1);
delays_us = [0, 0.2, 0.5, 1.0, 2.0];
powers_db = [0, -3, -6, -9, -12];
stem(delays_us, 10.^(powers_db/10), 'b', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Delay (\mus)'); ylabel('Relative Power');
title('Power Delay Profile (5-path VHF)'); grid on;

% Noisy channel frequency response (TX1→RX1, first data symbol, from rx1_sync)
subplot(2,1,2);
plot(1:cfg.N_active, 20*log10(abs(H_data(1).h11)), 'b-', 'LineWidth', 0.8);
xlabel('Subcarrier Index'); ylabel('|H| (dB)');
title(sprintf('Noisy Channel Freq Response — TX1→RX1 (SNR=%d dB)', snr_db));
grid on;

sgtitle('MIMO 2x2 — Channel');
%% ===== 12. OFDM Time Domain =====
fprintf('\n--- OFDM Time Domain ---\n');
figure(6); clf;

expected_sym_len = cfg.sym_len;
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

% Frequency-domain training
freq_data = zeros(cfg.N_fft, 1);
freq_data(cfg.idx_data1) = cfg.train_syms_1(1:cfg.half_active);
freq_data(cfg.idx_data2) = cfg.train_syms_1(cfg.half_active+1:end);
subplot(2,1,2);
stem(1:cfg.N_fft, real(freq_data), 'b', 'Marker','none','LineWidth', 1);
ylim([-1.2 1.2]); xlabel('FFT Bin'); ylabel('Symbol Value');
title(sprintf('TX1 Training — Freq Domain (%d active BPSK)', cfg.N_active));
grid on;

sgtitle('MIMO 2x2 — OFDM Modulation');
%% ===== 13. Sync Visualization (Phase Drift) =====
fprintf(' --- Sync Visualization --- ');
figure(7); clf;

% Subplot 1: Time sync — RX1 & RX2 correlation with TX1 training
[corr1, lag1] = xcorr(rx1, cfg.train_tx_1);
[corr2, lag2] = xcorr(rx2, cfg.train_tx_1);
subplot(3,1,1);
plot(lag1, abs(corr1), 'b-', 'LineWidth', 0.8); hold on;
plot(lag2, abs(corr2), 'r-', 'LineWidth', 0.8);
xline(frame_start, 'k--', 'LineWidth', 1.5); hold off;
xlabel('Lag (samples)'); ylabel('|Correlation|');
title(sprintf('Time Sync — RX1 & RX2 vs TX1 Training (peak@%d)', frame_start));
legend('RX1', 'RX2', 'Location', 'best'); grid on;

% Subplot 2-3: TX1 pilot subcarrier phase drift (BEFORE/AFTER CFO correction)
k_sc = 200;
pg_pos = cfg.pilot_group_pos;
n_pg = length(pg_pos);
t_ms = zeros(1, n_pg);
ph_bf = zeros(1, n_pg);
ph_af = zeros(1, n_pg);
for i = 1:n_pg
    p_sym = pg_pos(i);
    t_ms(i) = p_sym * cfg.sym_len / 1e6 * 1000;
    % TX1 pilot is first symbol of pilot group
    p_body_bf = rx1(frame_start + p_sym*cfg.sym_len + cfg.cp_len ...
                  : frame_start + (p_sym+1)*cfg.sym_len - 1);
    Y_bf = fft(p_body_bf, cfg.N_fft) / sqrt(cfg.N_fft);
    Y_bf_act = [Y_bf(cfg.idx_data1); Y_bf(cfg.idx_data2)];
    ph_bf(i) = angle(Y_bf_act(k_sc) / cfg.pilot_syms_1(k_sc));
    p_body_af = rx1_sync(frame_start + p_sym*cfg.sym_len + cfg.cp_len ...
                  : frame_start + (p_sym+1)*cfg.sym_len - 1);
    Y_af = fft(p_body_af, cfg.N_fft) / sqrt(cfg.N_fft);
    Y_af_act = [Y_af(cfg.idx_data1); Y_af(cfg.idx_data2)];
    ph_af(i) = angle(Y_af_act(k_sc) / cfg.pilot_syms_1(k_sc));
end
ph_bf = unwrap(ph_bf) * 180 / pi;
ph_af = unwrap(ph_af) * 180 / pi;

subplot(3,1,2);
plot(t_ms, ph_bf, 'ro-', 'LineWidth', 1.5, 'MarkerSize', 8); hold on;
expected = 360 * cfo_hz * t_ms * 1e-3;
expected = expected - expected(1) + ph_bf(1);
plot(t_ms, expected, 'b--', 'LineWidth', 1.0); hold off;
xlabel('Time (ms)'); ylabel('Phase (deg)');
title(sprintf('TX1 Pilot Subc %d Phase BEFORE Correction', k_sc));
legend('Measured', sprintf('Expected %.0f Hz', cfo_hz), 'Location', 'best'); grid on;

subplot(3,1,3);
plot(t_ms, ph_af, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 8);
yline(0, 'k--');
xlabel('Time (ms)'); ylabel('Phase (deg)');
title(sprintf('TX1 Pilot Subc %d Phase AFTER Correction (mean=%.2f deg)', k_sc, mean(ph_af)));
grid on;

fprintf('Phase drift before: %.2f deg/ms (expected %.2f)\\n', ...
        (ph_bf(end)-ph_bf(1))/(t_ms(end)-t_ms(1)), 360*cfo_hz*1e-3);
fprintf('Phase drift after:  %.4f deg/ms\\n', ...
        (ph_af(end)-ph_af(1))/(t_ms(end)-t_ms(1)));

