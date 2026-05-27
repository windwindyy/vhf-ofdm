function [rx_signal, chan] = vhf_channel(tx_signal)
% VHF 军用车载移动信道 — 5径多径 + 瑞利多普勒衰落
%
%   tx_signal  - 发射基带信号 (列向量)
%   rx_signal  - 接收基带信号 (列向量，长度 N + max_delay)
%   chan       - 结构体: delays, powers, fd, fading, fs

    % ---- 信道参数 (第2组 VHF) ----
    delays_us  = [0, 0.2, 0.5, 1.0, 2.0];   % 相对时延 (μs)
    powers_db  = [0, -3, -6, -9, -12];       % 相对功率 (dB)
    fc = 100e6;                                % 载频 (Hz)
    v  = 60 / 3.6;                             % 移动速度 (m/s)
    c  = 3e8;                                  % 光速
    fd = v / (c / fc);                         % 最大多普勒 ≈ 5.56 Hz
    fs = 1e6;                                  % 基带采样率 (1 MHz, 1 sample/μs)

    n_paths = length(delays_us);
    N = length(tx_signal);

    % ---- 功率归一化 ----
    powers_lin = 10.^(powers_db / 10);
    powers_lin = powers_lin / sum(powers_lin);

    % ---- 多径合成 (interp1 直接做分数延迟) ----
    max_delay_out = ceil(max(delays_us));          % 2 样本
    N_out = N + max_delay_out;

    % ---- 生成各径瑞利衰落 (输出长度 N_out) ----
    fading = zeros(n_paths, N_out);
    for p = 1:n_paths
        fading(p, :) = rayleigh_fading(N_out, fd, fs);
    end

    rx = zeros(N_out, 1);
    tx = tx_signal(:);

    for p = 1:n_paths
        d = delays_us(p);
        % 用 interp1 将信号沿时间轴移位 d 个样本: y[n] = x[n-d]
        t_in   = (1 : N)';
        t_out  = t_in - d;
        delayed = interp1(t_in, tx, t_out, 'linear', 0);  % 外推填 0

        % 补零到统一长度 N_out
        delayed = [delayed; zeros(N_out - length(delayed), 1)];
        delayed = delayed(1 : N_out);

        rx = rx + sqrt(powers_lin(p)) * (fading(p, :)' .* delayed);
    end

    rx_signal = rx;

    % ---- 输出结构体 ----
    chan.delays_us = delays_us;
    chan.powers_db = powers_db;
    chan.fd = fd;
    chan.fs = fs;
    chan.fading = fading;       % N_paths × N, 各径时变复增益
    chan.n_paths = n_paths;
    chan.max_delay = max_delay_out;

    fprintf('\n===== VHF Channel =====\n');
    fprintf('Paths:  %d  |  Delays: %.1f %.1f %.1f %.1f %.1f us  |  Powers: %d %d %d %d %d dB\n', ...
            n_paths, delays_us, powers_db);
    fprintf('fd:     %.2f Hz (v=%.0f km/h, fc=%.0f MHz)\n', fd, v*3.6, fc/1e6);
    fprintf('fs:     %.0f MHz  |  Max delay: %d samples\n', fs/1e6, max_delay_out);
    fprintf('Output: %d -> %d samples\n', N, length(rx_signal));
end
