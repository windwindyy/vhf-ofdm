function tx_bits = crc16_encode(data_bits, frame_len)
% CRC-16-CCITT 编码，按帧添加 CRC 校验位
%   data_bits - 信源比特 (1×n 向量)
%   frame_len - 每帧数据长度 (默认 1024)
%   tx_bits   - 编码后比特 (按帧拼接)

    if nargin < 2
        frame_len = 1024;
    end

    % CRC-16-CCITT: x^16 + x^12 + x^5 + 1
    poly = [1 0 0 0 1 0 0 0 0 0 0 1 0 0 0 0 1];  % 0x1021
    crc_len = 16;

    total_bits = length(data_bits);
    n_frames = ceil(total_bits / frame_len);

    % 补零到完整帧
    padded_len = n_frames * frame_len;
    padded = zeros(1, padded_len);
    padded(1:total_bits) = data_bits;

    tx_bits = zeros(1, padded_len + n_frames * crc_len);

    for f = 0:n_frames-1
        frame_data = padded(f*frame_len + 1 : (f+1)*frame_len);

        % CRC-16 移位寄存器
        reg = zeros(1, crc_len);
        for b = 1:frame_len
            fb = xor(frame_data(b), reg(1));
            reg = [reg(2:end), 0];
            if fb == 1
                reg = xor(reg, poly(2:end));
            end
        end

        tx_start = f*(frame_len + crc_len) + 1;
        tx_bits(tx_start : tx_start + frame_len - 1) = frame_data;
        tx_bits(tx_start + frame_len : tx_start + frame_len + crc_len - 1) = reg;
    end

    fprintf('CRC-16 encode: %d bits -> %d frames (%d data + %d CRC /frame)\n', ...
            total_bits, n_frames, frame_len, crc_len);
    fprintf('  Output: %d bits (overhead: %.2f%%)\n', ...
            length(tx_bits), crc_len / frame_len * 100);
end
