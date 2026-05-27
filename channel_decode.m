function decoded_bits = channel_decode(rx_data, dec_type)
% Viterbi decoder for convolutional code (K=7, R=1/2, [171,133])
%   rx_data      - received data: hard bits (0/1) or soft LLRs (real)
%   dec_type     - 'hard' (default) | 'soft' (unquantized LLR input)
%   decoded_bits - decoded bits (1×(n/2) vector)

    if nargin < 2 || isempty(dec_type)
        dec_type = 'hard';
    end

    trellis = poly2trellis(7, [171 133]);
    tblen = 7 * 5;  % traceback depth = 5 * K

    switch lower(dec_type)
        case 'hard'
            decoded_bits = vitdec(rx_data, trellis, tblen, 'trunc', 'hard');

        case 'soft'
            decoded_bits = vitdec(rx_data, trellis, tblen, 'trunc', 'unquant');

        otherwise
            error('Unknown decode type: %s. Use hard or soft', dec_type);
    end

    fprintf('Viterbi decode (%s): %d -> %d bits (tblen=%d)\n', ...
            dec_type, length(rx_data), length(decoded_bits), tblen);
end
