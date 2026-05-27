function cfg = ofdm_config()
% OFDM 物理层参数配置
%   cfg.N_fft       IFFT/FFT 点数
%   cfg.cp_len      CP 长度 (样本)
%   cfg.N_active    有效子载波数
%   cfg.guard_left  左保护带子载波数
%   cfg.guard_right 右保护带子载波数
%   cfg.half_active 有效子载波一半
%   cfg.sym_len     单个 OFDM 符号总样本数 (含 CP)

    cfg.N_fft = 512;
    cfg.cp_len = 8;
    cfg.N_active = 400;

    % Guard bands: DC(1) + left(55) + data(200) + Nyq(1) + data(200) + right(55) = 512
    cfg.guard_left = 55;
    cfg.guard_right = 55;

    cfg.half_active = cfg.N_active / 2;  % 200

    cfg.sym_len = cfg.N_fft + cfg.cp_len;  % 520

    % --- Subcarrier index lookup tables ---
    % Data 1st half: indices (57:256) in FFT input (bin 1 = DC)
    cfg.idx_data1 = (1 + cfg.guard_left + 1) : (1 + cfg.guard_left + cfg.half_active);
    % Data 2nd half: indices (258:457) in FFT input
    cfg.idx_data2 = (cfg.N_fft/2 + 1 + 1) : (cfg.N_fft/2 + 1 + cfg.half_active);

    % Verify
    assert(length(cfg.idx_data1) == cfg.half_active);
    assert(length(cfg.idx_data2) == cfg.half_active);

    fprintf('OFDM Config: N_fft=%d, CP=%d, active=%d, guard=[%d,%d]\n', ...
            cfg.N_fft, cfg.cp_len, cfg.N_active, cfg.guard_left, cfg.guard_right);
end
