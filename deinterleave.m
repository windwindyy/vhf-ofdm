function bits = deinterleave(int_bits, perm)
% 随机解交织
%   int_bits - 交织后比特
%   perm     - 交织用的排列向量
%   bits     - 恢复的原始比特

    N = length(int_bits);
    bits = zeros(1, N);
    bits(perm) = int_bits;

    fprintf('Deinterleave: %d bits restored\n', N);
end
