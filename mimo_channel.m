function [rx1, rx2] = mimo_channel(tx1, tx2)
% 2×2 MIMO VHF channel: 4 independent SISO links
% Each link has independent Rayleigh fading (driven by global rng state).
%   tx1, tx2 - TX signals (same length, column vectors)
%   rx1, rx2 - RX signals (column vectors)

    % TX1 → RX1
    [h11, ~] = vhf_channel(tx1);

    % TX1 → RX2
    [h12, ~] = vhf_channel(tx1);

    % TX2 → RX1
    [h21, ~] = vhf_channel(tx2);

    % TX2 → RX2
    [h22, ~] = vhf_channel(tx2);

    % Pad to same length (all should be N+2 already)
    max_len = max([length(h11), length(h12), length(h21), length(h22)]);
    rx1 = zeros(max_len, 1);
    rx2 = zeros(max_len, 1);
    rx1(1:length(h11)) = h11;  rx1(1:length(h21)) = rx1(1:length(h21)) + h21;
    rx2(1:length(h12)) = h12;  rx2(1:length(h22)) = rx2(1:length(h22)) + h22;

    fprintf('MIMO 2x2 channel: 4 independent VHF links\n');
    fprintf('  RX1: %d samples  RX2: %d samples\n', length(rx1), length(rx2));
end
