function rx_syms = ofdm_rx_demod(rx_data_sym, cfg)
% OFDM receiver: remove CP + FFT + extract active subcarriers
%   rx_data_sym - 520 time-domain samples (CP + IFFT body) of one OFDM symbol
%   cfg         - OFDM config from ofdm_config()
%   rx_syms     - 400 complex received symbols on active subcarriers

    % Remove CP (first cp_len samples)
    body = rx_data_sym(cfg.cp_len + 1 : end);  % 512 samples

    % FFT to frequency domain
    freq = fft(body, cfg.N_fft) / sqrt(cfg.N_fft);

    % Extract active subcarriers in the same order as TX mapping
    rx_syms = [freq(cfg.idx_data1); freq(cfg.idx_data2)];
end
