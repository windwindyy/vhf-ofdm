function coded_bits = channel_encode(tx_bits)
% 卷积码编码 (K=7, R=1/2, NASA标准)
%   tx_bits    - 输入比特 (1×n 向量)
%   coded_bits - 编码后比特 (1×(2*n) 向量, 码率1/2)

    % K=7, 生成多项式 [171, 133] (八进制)
    trellis = poly2trellis(7, [171 133]);

    coded_bits = convenc(tx_bits, trellis);

    fprintf('Conv. encode: K=7 R=1/2 [171,133]  %d -> %d bits\n', ...
            length(tx_bits), length(coded_bits));
end
