function bits = generate_source(n_bits)
% 生成随机二进制比特序列
%   n_bits - 总比特数
%   bits   - 1×n_bits 向量 (0/1)
    bits = randi([0, 1], 1, n_bits);
end
