function [frame_ok, ber, fer] = crc16_check(rx_bits, orig_bits, frame_len)
% CRC-16 verification and BER/FER statistics
%   rx_bits    - received bits after decoding (1×n vector)
%   orig_bits  - original source bits for BER comparison
%   frame_len  - data bits per frame (1024)
%   frame_ok   - 1×N_frames logical: CRC pass/fail per frame
%   ber        - bit error rate (on data bits only)
%   fer        - frame error rate (CRC fail / total frames)

    crc_len = 16;
    total = length(rx_bits);
    n_frames = total / (frame_len + crc_len);

    if mod(total, frame_len + crc_len) ~= 0
        warning('RX bits length %d not multiple of frame+CRC length %d', ...
                total, frame_len + crc_len);
    end

    % CRC-16-CCITT polynomial
    poly = [1 0 0 0 1 0 0 0 0 0 0 1 0 0 0 0 1];  % 0x1021

    frame_ok = false(1, n_frames);
    rx_data_only = zeros(1, n_frames * frame_len);

    for f = 0:n_frames-1
        fstart = f * (frame_len + crc_len) + 1;
        frame_data = rx_bits(fstart : fstart + frame_len - 1);
        rx_crc     = rx_bits(fstart + frame_len : fstart + frame_len + crc_len - 1);

        % Recompute CRC
        reg = zeros(1, crc_len);
        for b = 1:frame_len
            fb = xor(frame_data(b), reg(1));
            reg = [reg(2:end), 0];
            if fb == 1
                reg = xor(reg, poly(2:end));
            end
        end
        computed_crc = reg;

        frame_ok(f+1) = isequal(rx_crc, computed_crc);
        rx_data_only(f*frame_len + 1 : (f+1)*frame_len) = frame_data;
    end

    % BER on data bits only
    n_data = min(length(rx_data_only), length(orig_bits));
    bit_errors = sum(rx_data_only(1:n_data) ~= orig_bits(1:n_data));
    ber = bit_errors / n_data;

    % FER
    fer = sum(~frame_ok) / n_frames;

    fprintf('\n===== CRC-16 Check =====\n');
    fprintf('Frames: %d OK / %d total (FER = %.4f)\n', sum(frame_ok), n_frames, fer);
    fprintf('Bit errors: %d / %d (BER = %.2e)\n', bit_errors, n_data, ber);
end
