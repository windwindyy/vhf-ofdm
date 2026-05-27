function symbols = modulate(bits, mod_type)
% 符号调制 (Gray映射, 单位平均功率)
%   bits     - 输入比特 (1×n 向量, 0/1)
%   mod_type - 'QPSK' | '16QAM' | '64QAM'
%   symbols  - 复数符号 (1 × n/bpsym 向量)

    switch upper(mod_type)
        case 'QPSK'
            M = 4;
        case '16QAM'
            M = 16;
        case '64QAM'
            M = 64;
        otherwise
            error('不支持的调制方式: %s', mod_type);
    end

    bpsym = log2(M);

    N = length(bits);
    n_sym = floor(N / bpsym);
    valid_len = n_sym * bpsym;

    % bit → 整数 (每 bpsym 个 bit 组成一个整数)
    bits_reshaped = reshape(bits(1:valid_len), bpsym, n_sym)';
    sym_idx = bi2de(bits_reshaped, 'left-msb');

    % Gray 映射, 单位平均功率
    symbols = qammod(sym_idx, M, 'UnitAveragePower', true);
    symbols = symbols(:).';

    fprintf('Modulation: %s (M=%d, %d bit/sym)  %d bits -> %d symbols\n', ...
            mod_type, M, bpsym, N, n_sym);
end
