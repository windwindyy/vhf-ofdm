function frame_start = ofdm_time_sync(rx_signal, cfg)
% Time synchronization: cross-correlation with known training symbol
%   rx_signal   - received baseband signal
%   cfg         - OFDM config (must contain .train_tx, .train_syms)
%   frame_start - sample index where OFDM frame begins

    % Rebuild training symbol reference (same as TX: rng(7), BPSK ±1)
    train_ref = cfg.train_tx;

    % Cross-correlation
    [corr, lag] = xcorr(rx_signal, train_ref);

    % Peak magnitude = frame start
    [~, peak_idx] = max(abs(corr));
    frame_start = lag(peak_idx) + 1;    % lag→sample offset: lag=0 → starts at sample 1

    % Clamp to valid range (channel delay may shift peak slightly)
    frame_start = max(1, min(frame_start, length(rx_signal)));

    % Sanity check
    assert(frame_start > 0 && frame_start <= length(rx_signal), ...
           'Frame start %d out of range [1, %d]', frame_start, length(rx_signal));

    fprintf('Time sync: frame start at sample %d (corr peak = %.2f)\n', ...
            frame_start, abs(corr(peak_idx)));
end
