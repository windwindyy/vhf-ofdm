function out = demodulate(symbols, mod_type, output_type)
% Symbol demodulation with hard or soft output
%   symbols     - received complex symbols
%   mod_type    - 'QPSK' | '16QAM' | '64QAM'
%   output_type - 'hard' (0/1 bits) | 'soft' (decision variables for Viterbi)
%
% Soft output: real values, sign = hard decision (+→0, -→1),
% magnitude = confidence. Directly usable by vitdec(..., 'unquant').
% For QPSK: I/Q components scaled to ±1. For QAM: via qamdemod approxllr.

    if nargin < 3 || isempty(output_type)
        output_type = 'hard';
    end

    switch upper(mod_type)
        case 'QPSK',  M = 4;
        case '16QAM', M = 16;
        case '64QAM', M = 64;
        otherwise
            error('Unsupported modulation: %s', mod_type);
    end

    bpsym = log2(M);

    switch lower(output_type)
        case 'hard'
            sym_idx = qamdemod(symbols(:), M, 'UnitAveragePower', true);
            bits_mat = de2bi(sym_idx, bpsym, 'left-msb');
            out = reshape(bits_mat.', 1, []);

        case 'soft'
            syms = symbols(:);
            n_sym = length(syms);

            switch upper(mod_type)
                case 'QPSK'
                    % I/Q components scaled to ±1.
                    % QPSK constellation: (±1/√2 ± j/√2).
                    % Multiply by √2 to get ±1 on each axis.
                    % MATLAB qammod gray mapping: MSB=0→I-, MSB=1→I+;
                    % LSB=0→Q+, LSB=1→Q-.  So negate I for correct sign.
                    n_out = 2 * n_sym;
                    out = zeros(1, n_out);
                    out(1:2:end) = -real(syms)' * sqrt(2);  % b0 on I (inverted)
                    out(2:2:end) =  imag(syms)' * sqrt(2);  % b1 on Q

                case {'16QAM', '64QAM'}
                    % approxllr is acceptable for higher-order QAM
                    % since the constellation normalization is handled internally
                    llr_mat = qamdemod(syms, M, 'UnitAveragePower', true, ...
                                       'OutputType', 'approxllr');
                    out = reshape(llr_mat.', 1, []);
            end

        otherwise
            error('Unknown output type: %s. Use hard or soft', output_type);
    end

    fprintf('Demodulation: %s %s -> %d %s\n', ...
            mod_type, output_type, length(out), ...
            ternary(strcmp(output_type,'hard'), 'bits', 'soft values'));
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
