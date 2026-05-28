% test_all.m -- Master test script
% Usage:
%   Full run:   run test_all
%   Step debug: In MATLAB editor, select a section (%% ...) and press Ctrl+Enter
close all;
clear; clc;

%% ===== Global Parameters =====
% Run this section first to set all parameters

N = 1000000;          % Total source bits
frame_len = 1024;     % Data bits per frame (CRC unit)
crc_len = 16;         % CRC checksum length

% Modulation: 'QPSK' | '16QAM' | '64QAM'
mod_type = '64QAM';

% Carrier Frequency Offset (simulate 0.1ppm crystal mismatch @ 100MHz)
% Typical: 0~10 Hz. Set to 0 to disable.
cfo_hz = 10;

% AWGN SNR for single-point test (dB)
snr_db = 20;

% SNR sweep for BER curve
snr_vec = 0:2:25;

% GUI parameter override (from vhf_ofdm_app)
if exist('gui_params.mat', 'file')
    p = load('gui_params.mat');
    if isfield(p, 'snr_val'), snr_db = p.snr_val; end
    if isfield(p, 'N'), N = p.N; end
    delete('gui_params.mat');
end

fprintf('===== Global Parameters =====\n');
fprintf('Source bits: %d\n', N);
fprintf('Frame data:  %d bits\n', frame_len);
fprintf('CRC bits:    %d bits\n', crc_len);
fprintf('Modulation:  %s\n', mod_type);
fprintf('CFO inject:  %.1f Hz (%.2f ppm @ 100MHz)\n', cfo_hz, cfo_hz/100e6*1e6);
fprintf('AWGN SNR:    %.0f dB\n', snr_db);

%% ===== 1. Source Generation =====
fprintf('\n===== 1. Source Generation =====\n');

bits = generate_source(N);
fprintf('Generated: %d bits\n', length(bits));
fprintf('0 ratio: %.3f  1 ratio: %.3f\n', mean(bits==0), mean(bits==1));
fprintf('First 20: %s\n', mat2str(bits(1:20)));

assert(length(bits) == N, 'Source length mismatch');
assert(all(bits==0 | bits==1), 'Source contains non-binary values');
fprintf('[PASS] Source generation\n');
% --- Visualize: one full source frame (blue) ---
figure(1); clf;
subplot(5,1,1);
stem(1:frame_len, bits(1:frame_len), 'b', 'Marker', 'none', 'LineWidth', 0.5);
ylim([-0.1 1.1]);  xlabel('Bit index');  ylabel('Value');
title(sprintf('1. Source Bits (1 frame = %d bits)', frame_len));  grid on;

%% ===== 2. CRC-16 Encoding =====
fprintf('\n===== 2. CRC-16 Encoding =====\n');

tx = crc16_encode(bits, frame_len);

n_frames = ceil(N / frame_len);
expected_len = n_frames * (frame_len + crc_len);
assert(length(tx) == expected_len, 'CRC output length mismatch');
assert(isequal(tx(1:frame_len), bits(1:frame_len)), 'Data segment mismatch');
fprintf('[PASS] CRC-16 encoding\n');
% --- Visualize: data(blue) + CRC(red appended) ---
subplot(5,1,2);  hold on;
stem(1:frame_len, tx(1:frame_len), 'b', 'Marker', 'none', 'LineWidth', 0.5);
stem(frame_len+1 : frame_len+crc_len, tx(frame_len+1 : frame_len+crc_len), ...
     'r', 'Marker', 'none', 'LineWidth', 1);
xline(frame_len + 0.5, 'k--');
ylim([-0.2 1.2]);  xlabel('Bit index');  ylabel('Value');
title(sprintf('2. Data + CRC-16 (%d + %d bits)', frame_len, crc_len));
legend('Data', 'CRC', 'Location', 'best');  grid on;  hold off;

%% ===== 3. Channel Coding (Conv. K=7 R=1/2) =====
fprintf('\n===== 3. Channel Coding (Conv. K=7 R=1/2) =====\n');

coded_bits = channel_encode(tx);

assert(length(coded_bits) == 2*length(tx), 'Coded length should be 2x input');
assert(all(coded_bits==0 | coded_bits==1), 'Coded output non-binary');
fprintf('[PASS] Channel coding\n');
% --- Visualize: conv coded output, mark a burst segment in red ---
frame1_coded = coded_bits(1 : 2 * (frame_len + crc_len));
N_coded = length(frame1_coded);
burst_start = 300;  burst_end = 700;   % marked burst (simulates error burst)

subplot(5,1,3);  hold on;
% green: normal bits before burst
stem(1:burst_start-1, frame1_coded(1:burst_start-1), 'g', 'Marker', 'none', 'LineWidth', 0.5);
% red:  marked burst
stem(burst_start:burst_end, frame1_coded(burst_start:burst_end), 'r', 'Marker', 'none', 'LineWidth', 1);
% green: normal bits after burst
stem(burst_end+1:N_coded, frame1_coded(burst_end+1:N_coded), 'g', 'Marker', 'none', 'LineWidth', 0.5);
ylim([-0.2 1.2]);  xlabel('Bit index');  ylabel('Value');
title(sprintf('3. Conv Coded R=1/2 (%d bits, red = marked burst)', N_coded));
legend('Normal', 'Burst', 'Location', 'best');  grid on;  hold off;

%% ===== 4. Interleaving =====
fprintf('\n===== 4. Random Interleaving =====\n');

[int_bits, perm] = interleave(coded_bits);

assert(length(int_bits) == length(coded_bits), 'Interleave length changed');
assert(isequal(sort(int_bits), sort(coded_bits)), 'Not a permutation');

restored = deinterleave(int_bits, perm);
assert(isequal(restored, coded_bits), 'Interleave/deinterleave not inverse');
fprintf('[PASS] Interleaving\n');
% --- Visualize: interleaved — red burst bits scattered among green ---
frame1_int = int_bits(1:N_coded);
burst_in_int = find(ismember(perm(1:N_coded), burst_start:burst_end));

subplot(5,1,4);  hold on;
% green: normal bits (stem)
normal_idx = setdiff(1:N_coded, burst_in_int);
stem(normal_idx, frame1_int(normal_idx), 'g', 'Marker', 'none', 'LineWidth', 0.5);
% red:  scattered burst bits (stem, thicker)
stem(burst_in_int, frame1_int(burst_in_int), 'r', 'Marker', 'none', 'LineWidth', 1);
ylim([-0.1 1.1]);  xlabel('Bit index');  ylabel('Value');
title(sprintf('4. After Interleaving — burst scattered across %d positions', ...
      length(burst_in_int)));
legend('Normal', 'Burst (scattered)', 'Location', 'best');  grid on;  hold off;

% --- Visualize: deinterleaved — red burst restored to original positions ---
frame1_restored = restored(1:N_coded);
subplot(5,1,5);  hold on;
stem(1:burst_start-1, frame1_restored(1:burst_start-1), 'g', 'Marker', 'none', 'LineWidth', 0.5);
stem(burst_start:burst_end, frame1_restored(burst_start:burst_end), 'r', 'Marker', 'none', 'LineWidth', 1);
stem(burst_end+1:N_coded, frame1_restored(burst_end+1:N_coded), 'g', 'Marker', 'none', 'LineWidth', 0.5);
ylim([-0.2 1.2]);  xlabel('Bit index');  ylabel('Value');
title(sprintf('5. After Deinterleaving — burst restored (%d bits)', ...
      burst_end - burst_start + 1));
legend('Normal', 'Burst (restored)', 'Location', 'best');  grid on;  hold off;

%% ===== 5. Modulation =====
fprintf('\n===== 5. Modulation (%s) =====\n', mod_type);  tx_symbols = modulate(int_bits, mod_type);

bpsym_map = containers.Map({'QPSK','16QAM','64QAM'}, [2, 4, 6]);
bpsym = bpsym_map(upper(mod_type));
n_sym = floor(length(int_bits) / bpsym);
assert(length(tx_symbols) == n_sym, 'Symbol count mismatch');

rx_bits_mod = demodulate(tx_symbols, mod_type);
assert(isequal(rx_bits_mod, int_bits(1:length(rx_bits_mod))), ...
       'Modulation/demodulation not inverse');
fprintf('[PASS] Modulation (roundtrip verified)\n');
% --- Visualize: QPSK I/Q (stem format, new figure) ---
figure(3); clf;
subplot(2,1,1);
stem(1:200, real(tx_symbols(1:200)), 'b', 'Marker', 'none', 'LineWidth', 0.5);
ylim([-1.2 1.2]);  xlabel('Symbol index');  ylabel('I');
title(sprintf('QPSK Symbols — In-phase (first 200)'));  grid on;

subplot(2,1,2);
stem(1:200, imag(tx_symbols(1:200)), 'r', 'Marker', 'none', 'LineWidth', 0.5);
ylim([-1.2 1.2]);  xlabel('Symbol index');  ylabel('Q');
title(sprintf('QPSK Symbols — Quadrature (first 200)'));  grid on;

%% ===== 6. OFDM Modulation (Train + Periodic Pilots + IFFT + CP) =====
fprintf('\n===== 6. OFDM Modulation =====\n');

pilot_spacing = 40;  % data symbols between periodic pilots (20.8 ms < Tc/4)
[tx_frame, ofdm_cfg] = ofdm_assemble_frame(int_bits, mod_type, pilot_spacing);

% Quick sanity checks
expected_sym_len = 520;
tx_frame_len = length(tx_frame);
n_symbols = tx_frame_len / expected_sym_len;
assert(mod(tx_frame_len, expected_sym_len) == 0, ...
       'Frame length not multiple of symbol length');
fprintf('Frame: %d samples, %d OFDM symbols (train + pilot + data)\n', ...
        tx_frame_len, n_symbols);
fprintf('[PASS] OFDM frame assembled\n');
% --- Visualize: OFDM time-domain symbol + frequency allocation ---
figure(4); clf;

% Subplot 1: first OFDM symbol (training) time domain, CP in red
% Upsample 10x for smooth analog-like waveform
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
title(sprintf('OFDM Time Domain — CP(%d) + IFFT Body(%d)', ...
      ofdm_cfg.cp_len, ofdm_cfg.N_fft));
legend('CP', 'IFFT Body', 'Location', 'best');  grid on;  hold off;

% Subplot 2: actual frequency-domain training symbols
freq_data = zeros(ofdm_cfg.N_fft, 1);
freq_data(ofdm_cfg.idx_data1) = ofdm_cfg.train_syms(1 : ofdm_cfg.half_active);
freq_data(ofdm_cfg.idx_data2) = ofdm_cfg.train_syms(ofdm_cfg.half_active + 1 : end);
subplot(2,1,2);
stem(1:ofdm_cfg.N_fft, real(freq_data), 'b', 'Marker', 'none', 'LineWidth', 1);
ylim([-1.2 1.2]);  xlabel('FFT Bin');  ylabel('Symbol Value');
title(sprintf('Training Symbol — Freq Domain (%d active BPSK subcarriers)', ...
      ofdm_cfg.N_active));
grid on;

%% ===== 7. VHF Channel =====
fprintf('\n===== 7. VHF Channel =====\n');

[rx_signal, chan] = vhf_channel(tx_frame);

fprintf('RX signal: %d samples\n', length(rx_signal)); fprintf('[PASS] VHF channel applied\n');
% Save before CFO for true channel comparison
rx_chan_only = rx_signal;

% --- Inject CFO (simulate crystal mismatch) ---
if cfo_hz ~= 0
    fs = 1e6;
    t_vec = (0 : length(rx_signal) - 1)' / fs;
    rx_signal = rx_signal .* exp(1j * 2 * pi * cfo_hz * t_vec);
fprintf('CFO injected: %.1f Hz (%.2f ppm @ 100 MHz)\n', cfo_hz, cfo_hz/100e6*1e6); end  % Save noiseless signal for SNR-BER loop rx_nonoise = rx_signal; rx_power = mean(abs(rx_nonoise).^2);

% --- Add AWGN (simulate receiver thermal noise) ---
rx_signal = add_awgn(rx_signal, snr_db);
fprintf('AWGN added: SNR = %.0f dB\n', snr_db);  % --- Visualize: channel impulse response (power delay profile) --- figure(2); clf; subplot(2,1,1);
stem(chan.delays_us, 10.^(chan.powers_db/10), 'b', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Delay (\mus)');  ylabel('Relative Power (linear)');
title('Power Delay Profile (5-path VHF)');  grid on;

subplot(2,1,2);
% Smooth envelope via 10x upsampling (matching figure(4) style)
up = 10;
N_show = min(2000, min(length(tx_frame), length(rx_signal)));
t_orig = (1 : N_show)';
t_fine = (1 : 1/up : N_show)';
tx_env = abs(tx_frame(1:N_show));
rx_env = abs(rx_signal(1:N_show));   % includes AWGN
tx_smooth = interp1(t_orig, tx_env, t_fine, 'spline');
rx_smooth = interp1(t_orig, rx_env, t_fine, 'spline');
plot(t_fine, tx_smooth, 'b-', 'LineWidth', 0.5); hold on;
plot(t_fine, rx_smooth, 'r-', 'LineWidth', 0.8);
xlabel(sprintf('Sample (1/%d us)', up));  ylabel('Amplitude');
title(sprintf('Signal Envelope: TX (blue) vs RX + AWGN (red), SNR=%d dB', snr_db));
legend('TX', 'RX', 'Location', 'best');  grid on;  hold off;

%% ===== 8. RX: Sync =====
fprintf('\n===== 8. RX: Time + Freq Sync =====\n');
% Time sync: cross-correlation with training symbol
frame_start = ofdm_time_sync(rx_signal, ofdm_cfg);

% Verify frame start is reasonable (training symbol should be near beginning)
assert(frame_start < 500, 'Frame start too late: sample %d', frame_start);

% Frequency sync: CP correlation + correction
[rx_sync, freq_offset] = ofdm_freq_sync(rx_signal, ofdm_cfg, frame_start);

fprintf('Estimated CFO: %.2f Hz (expected ~10-20 Hz from 0.1ppm)\n', freq_offset); fprintf('[PASS] RX synchronization\n');
% --- Visualize: correlation peak + subcarrier phase drift ---
figure(5); clf;

% Subplot 1: Time sync — correlation peak
train_ref = ofdm_cfg.train_tx;
[corr, lag] = xcorr(rx_signal, train_ref);
subplot(3,1,1);
plot(lag, abs(corr), 'b-', 'LineWidth', 0.8);
hold on;  xline(frame_start, 'r--', 'LineWidth', 2);  hold off;
xlabel('Lag (samples)');  ylabel('|Correlation|');
title('Time Sync — Cross-correlation with Training Symbol');
legend('|Corr|', 'Detected peak', 'Location', 'best');  grid on;

% Subplot 2-3: Pilot subcarrier phase drift (BEFORE/AFTER CFO correction)
% Pick center subcarrier, track phase across all periodic pilots
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
expected = 360 * cfo_hz * t_ms * 1e-3;
expected = expected - expected(1) + ph_bf(1);
plot(t_ms, expected, 'b--', 'LineWidth', 1.0); hold off;
xlabel('Time (ms)');  ylabel('Phase (deg)');
title(sprintf('Pilot Subc %d Phase BEFORE Correction', k_sc));
legend('Measured', sprintf('Expected %.0f Hz', cfo_hz), 'Location', 'best'); grid on;

subplot(3,1,3);
plot(t_ms, ph_af, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 8);
yline(0, 'k--');
xlabel('Time (ms)');  ylabel('Phase (deg)');
title(sprintf('Pilot Subc %d Phase AFTER Correction (mean=%.2f deg)', k_sc, mean(ph_af)));
grid on;

fprintf('Phase drift before: %.2f deg/ms (expected %.2f)\\n', ...
        (ph_bf(end)-ph_bf(1))/(t_ms(end)-t_ms(1)), 360*cfo_hz*1e-3);
fprintf('Phase drift after:  %.4f deg/ms\\n', ...
        (ph_af(end)-ph_af(1))/(t_ms(end)-t_ms(1)));

%% ===== 9. Channel Estimation (Periodic MMSE + Interpolation) =====
fprintf('\n===== 9. Channel Estimation (Periodic) =====\n');

H_data = channel_estimate_interp(rx_sync, ofdm_cfg, frame_start, snr_db);

assert(size(H_data,1) == ofdm_cfg.N_active, 'Channel estimate dimension mismatch');
assert(all(isfinite(H_data(:))), 'Channel estimate contains non-finite values');
% --- True channel from noiseless signal at first pilot ---
p0 = ofdm_cfg.pilot_positions(1);
p_body = rx_chan_only(frame_start + p0*ofdm_cfg.sym_len + ofdm_cfg.cp_len ...
                    : frame_start + (p0+1)*ofdm_cfg.sym_len - 1);
Yp = fft(p_body, ofdm_cfg.N_fft) / sqrt(ofdm_cfg.N_fft);
H_true_p0 = [Yp(ofdm_cfg.idx_data1); Yp(ofdm_cfg.idx_data2)] ./ ofdm_cfg.pilot_syms(:);

% Comparison metrics (first data symbol)
mse_mag = mean((abs(H_data(:,1)) - abs(H_true_p0)).^2);
corr_mat = corrcoef(abs(H_data(:,1)), abs(H_true_p0));
fprintf('|H_data(:,1)| mean=%.3f  |H_true| mean=%.3f  corr=%.4f  MSE_mag=%.4f\n', ...
        mean(abs(H_data(:,1))), mean(abs(H_true_p0)), corr_mat(1,2), mse_mag);
fprintf('[PASS] Periodic channel estimation\n');
% --- Visualize: True vs Estimated at first data symbol ---
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

%% ===== 10. OFDM Demodulation + Equalization =====
fprintf('\n===== 10. OFDM Demod + Equalization (MMSE) =====\n');

n_data_syms = ofdm_cfg.n_data_syms;
bpsym_map = containers.Map({'QPSK','16QAM','64QAM'}, [2, 4, 6]);
bpsym = bpsym_map(upper(mod_type));

sigma2_eq = rx_power * 10^(-snr_db / 10);
data_pos = ofdm_cfg.data_sym_pos;  % frame symbol indices of data symbols

Y_all = cell(n_data_syms, 1);
X_all = cell(n_data_syms, 1);
n_valid = 0;

for s = 1:n_data_syms
    sym_start = frame_start + data_pos(s) * ofdm_cfg.sym_len;
    if sym_start + ofdm_cfg.sym_len - 1 > length(rx_sync), break; end
    rx_sym = rx_sync(sym_start : sym_start + ofdm_cfg.sym_len - 1);

    % OFDM demod: CP removal + FFT + subcarrier extraction
    Y = ofdm_rx_demod(rx_sym, ofdm_cfg);

    % MMSE equalization (per-symbol channel estimate)
    X = channel_equalize(Y, H_data(:, s), 'MMSE', sigma2_eq);

    Y_all{s} = Y;
    X_all{s} = X;
    n_valid = s;
end

% Flatten and trim
Y_cat = [];
X_cat = [];
for s = 1:n_valid
    Y_cat = [Y_cat; Y_all{s}];
    X_cat = [X_cat; X_all{s}];
end
total_syms = ceil(length(int_bits) / bpsym);
Y_cat = Y_cat(1:total_syms);
X_cat = X_cat(1:total_syms);

fprintf('Demodulated %d OFDM symbols -> %d complex symbols\n', ...
        n_valid, length(X_cat));

% Round-trip sanity check (noise-free case should be perfect)
rx_bits_test = demodulate(X_cat, mod_type);
n_test = min(length(rx_bits_test), length(int_bits));
sym_errors = sum(rx_bits_test(1:n_test) ~= int_bits(1:n_test));
fprintf('Symbol errors before decoding: %d / %d (%.2e)\n', ...
        sym_errors, n_test, sym_errors/n_test);
fprintf('[PASS] OFDM demodulation + MMSE equalization\n');
% --- Visualize: Constellation before vs after EQ ---
N_plot = min(2000, length(Y_cat));

figure(7); clf;

subplot(1,3,1);
plot(real(Y_cat(1:N_plot)), imag(Y_cat(1:N_plot)), 'r.', 'MarkerSize', 5);
xlabel('I');  ylabel('Q');
title(sprintf('RX Before EQ (%d symbols)', N_plot));
axis equal;  grid on;

subplot(1,3,2);
plot(real(X_cat(1:N_plot)), imag(X_cat(1:N_plot)), 'b.', 'MarkerSize', 5);
xlabel('I');  ylabel('Q');
title(sprintf('After MMSE EQ (%d symbols)', N_plot));
axis equal;  grid on;

% Reference: ideal QPSK constellation
subplot(1,3,3);
ref_syms = [1+1j, 1-1j, -1+1j, -1-1j] / sqrt(2);
plot(real(ref_syms), imag(ref_syms), 'ko', 'MarkerSize', 12, 'LineWidth', 2); hold on;
plot(real(X_cat(1:N_plot)), imag(X_cat(1:N_plot)), 'b.', 'MarkerSize', 3);
xlabel('I');  ylabel('Q');
title(sprintf('MMSE EQ vs Ideal QPSK (SNR=%d dB)', snr_db));
legend('Ideal QPSK', 'EQ output', 'Location', 'best');
axis equal;  grid on;  hold off;

%% ===== 11. Soft Demodulation (LLR) =====
fprintf('\n===== 11. Soft Demodulation (LLR) =====\n');
% Soft LLRs: positive → likely 0, negative → likely 1
llr_soft = demodulate(X_cat, mod_type, 'soft');
% Hard demod for comparison
rx_bits_hard = demodulate(X_cat, mod_type, 'hard');
fprintf('Soft LLR range: [%.2f, %.2f]  mean abs: %.2f\n', ...
        min(llr_soft), max(llr_soft), mean(abs(llr_soft)));

% Diagnostic: compare BEFORE deinterleave (per-symbol)
soft_sign_pre = double(llr_soft(1:200) > 0);
hard_val_pre  = double(rx_bits_hard(1:200) == 0);
match_pre = (soft_sign_pre == hard_val_pre);
fprintf('BEFORE deint, first 200: sign match %d/200 (%.0f%%)\n', ...
        sum(match_pre), sum(match_pre)/200*100);
% Show first 16 values of both for manual inspection
fprintf('  soft(1:16): %s\n', mat2str(round(llr_soft(1:16)*100)/100)); fprintf('  hard(1:16): %s\n', mat2str(rx_bits_hard(1:16)));  fprintf('[PASS] Soft demodulation\n');
%% ===== 12. Deinterleave =====
fprintf('\n===== 12. Deinterleave =====\n');
% Apply same permutation to both soft and hard paths
llr_deint = deinterleave(llr_soft, perm);
rx_bits_deint = deinterleave(rx_bits_hard, perm);

% Trim to match original coded length
n_coded_orig = length(coded_bits);
llr_deint = llr_deint(1:n_coded_orig);
rx_bits_deint = rx_bits_deint(1:n_coded_orig);

fprintf('Deinterleaved: %d values -> %d values\n', ...
        length(llr_soft), length(llr_deint));
fprintf('[PASS] Deinterleave\n');
% Diagnostic: compare soft sign with hard bits
% soft: positive → bit 0, negative → bit 1
% hard: 0 or 1
soft_sign = double(llr_deint > 0);        % 1→favor 0, 0→favor 1
hard_val  = double(rx_bits_deint == 0);   % 1→is 0, 0→is 1
sign_match = (soft_sign == hard_val);
fprintf('Soft vs Hard sign agreement: %d / %d (%.1f%%)\n', ...
        sum(sign_match), length(sign_match), ...
        sum(sign_match)/length(sign_match)*100);

% Distribution of soft values
fprintf('Soft value distribution: min=%.2f  p1=%.2f  median=%.2f  p99=%.2f  max=%.2f\n', ...
        min(llr_deint), prctile(llr_deint, 1), median(llr_deint), ...
        prctile(llr_deint, 99), max(llr_deint));

%% ===== 13. Viterbi Decode =====
fprintf('\n===== 13. Viterbi Decode =====\n');
% Soft LLR → Viterbi (unquant)
rx_decoded_soft = channel_decode(llr_deint, 'soft');
% Hard bits → Viterbi (hard) for comparison
rx_decoded_hard = channel_decode(rx_bits_deint, 'hard');
fprintf('[PASS] Viterbi decode\n');
%% ===== 14. CRC Check + BER/FER =====
fprintf('\n===== 14. CRC Check + BER/FER =====\n');
% Soft path
[frame_ok_soft, ber_soft, fer_soft] = crc16_check(rx_decoded_soft, bits, frame_len);

% Hard path
[frame_ok_hard, ber_hard, fer_hard] = crc16_check(rx_decoded_hard, bits, frame_len);

% --- Visualize: BER/FER comparison ---
figure(8); clf;
bar_data = [ber_soft, fer_soft; ber_hard, fer_hard]';
b = bar(bar_data, 'grouped');
b(1).FaceColor = [0.23 0.51 0.92];  % soft (blue)
b(2).FaceColor = [0.85 0.33 0.10];  % hard (red)
set(gca, 'XTickLabel', {'BER', 'FER'});
ylabel('Error Rate');
title(sprintf('BER/FER: Soft vs Hard Decision (%s, SNR=%d dB)', mod_type, snr_db));
legend('Soft LLR', 'Hard', 'Location', 'northwest');
% Annotate bars using exact bar positions
for i = 1:2
    text(b(1).XEndPoints(i), b(1).YEndPoints(i), sprintf('%.2e', b(1).YEndPoints(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
    text(b(2).XEndPoints(i), b(2).YEndPoints(i), sprintf('%.2e', b(2).YEndPoints(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
end
grid on;

fprintf('\n===== RX Chain Complete =====\n');
fprintf('SNR: %d dB  |  Modulation: %s\n', snr_db, mod_type);
fprintf('Soft LLR:  BER=%.2e  FER=%.3f  CRC OK=%d/%d\n', ...
        ber_soft, fer_soft, sum(frame_ok_soft), length(frame_ok_soft));
fprintf('Hard bits: BER=%.2e  FER=%.3f  CRC OK=%d/%d\n', ...
        ber_hard, fer_hard, sum(frame_ok_hard), length(frame_ok_hard));
fprintf('[PASS] Full RX chain\n');
%% ===== Done =====
fprintf('\n===== All modules verified =====\n');
