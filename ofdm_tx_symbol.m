function tx_sym = ofdm_tx_symbol(data_syms, cfg)
% OFDM modulation of one symbol: subcarrier mapping + IFFT + CP
%   data_syms - 400 complex modulation symbols (column vector)
%   cfg       - OFDM config from ofdm_config()
%   tx_sym    - 520 time-domain samples (CP + IFFT output)

    assert(length(data_syms) == cfg.N_active, ...
           'Expected %d active symbols, got %d', cfg.N_active, length(data_syms));

    % Build frequency-domain vector (DC + guard bands already zero)
    freq = zeros(cfg.N_fft, 1);
    freq(cfg.idx_data1) = data_syms(1 : cfg.half_active);
    freq(cfg.idx_data2) = data_syms(cfg.half_active + 1 : end);

    % IFFT to time domain
    time_sym = ifft(freq, cfg.N_fft) * sqrt(cfg.N_fft);  % power normalization

    % Prepend CP (copy last cp_len samples)
    tx_sym = [time_sym(end - cfg.cp_len + 1 : end); time_sym];

    fprintf('OFDM symbol: %d freq bins -> %d time samples (CP=%d)\n', ...
            cfg.N_fft, length(tx_sym), cfg.cp_len);
end
