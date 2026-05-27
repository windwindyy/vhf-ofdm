function [int_bits, perm] = interleave(bits, perm)
% 随机交织
%   bits    - 输入比特 (1×n 向量)
%   perm    - 排列向量 (可选, 首次调用自动生成)
%   int_bits- 交织后比特
%   perm    - 排列向量 (用于解交织)

    N = length(bits);

    if nargin < 2
        rng(42);                    % 固定种子, 保证可复现
        perm = randperm(N);
    end

    int_bits = bits(perm);

    fprintf('Interleave: %d bits (random permutation)\n', N);
end
