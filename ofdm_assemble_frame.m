function [tx_frame, cfg] = ofdm_assemble_frame(coded_bits, mod_type, pilot_spacing)
% Assemble OFDM TX frame with optional periodic pilots.
%   coded_bits    - interleaved coded bits
%   mod_type      - 'QPSK' | '16QAM' | '64QAM'
%   pilot_spacing - data symbols between periodic pilots (default Inf = single pilot)
%
% Frame with single pilot (pilot_spacing=Inf):
%   [Train | Pilot | Data_1 ... Data_N]
%
% Frame with periodic pilots (pilot_spacing=K):
%   [Train | Pilot | D_1..D_K | Pilot | D_{K+1}..D_{2K} | Pilot | ...]
%
% cfg.pilot_positions stores symbol indices of all pilots (1-indexed, train at idx 0).

    cfg = ofdm_config();

    if nargin < 3 || isempty(pilot_spacing) || pilot_spacing <= 0
        pilot_spacing = Inf;
    end

    bpsym_map = containers.Map({'QPSK','16QAM','64QAM'}, [2, 4, 6]);
    bpsym = bpsym_map(upper(mod_type));
    bits_per_ofdm_sym = cfg.N_active * bpsym;

    % --- Training symbol ---
    rng(7);
    train_syms = 2 * randi([0 1], cfg.N_active, 1) - 1;
    train_tx = ofdm_tx_symbol(train_syms, cfg);

    % --- Pilot symbol (same BPSK sequence reused for all periodic pilots) ---
    rng(13);
    pilot_syms = 2 * randi([0 1], cfg.N_active, 1) - 1;
    pilot_tx = ofdm_tx_symbol(pilot_syms, cfg);

    % --- Data symbols ---
    n_data_syms = ceil(length(coded_bits) / bits_per_ofdm_sym);
    padded_len = n_data_syms * bits_per_ofdm_sym;
    padded_bits = zeros(1, padded_len);
    padded_bits(1:length(coded_bits)) = coded_bits;
    all_mod_syms = modulate(padded_bits, mod_type);

    if isinf(pilot_spacing)
        % Original: single block pilot after training
        data_tx = [];
        for s = 1:n_data_syms
            sym_start = (s-1) * cfg.N_active + 1;
            sym_end   = s * cfg.N_active;
            data_tx = [data_tx; ofdm_tx_symbol(all_mod_syms(sym_start:sym_end), cfg)];
        end
        tx_frame = [train_tx; pilot_tx; data_tx];
        cfg.pilot_positions = 1;
        cfg.data_sym_pos = (2 : n_data_syms+1);  % data at sym 2,3,...,n+1

    else
        K = pilot_spacing;
        n_pilot_groups = ceil(n_data_syms / K);
        n_pilots = n_pilot_groups + 1;

        tx_frame = train_tx;
        pilot_pos = zeros(1, n_pilots);
        data_sym_pos = zeros(1, n_data_syms);
        data_count = 0;
        sym_idx = 0;

        for g = 0:n_pilot_groups
            sym_idx = sym_idx + 1;
            tx_frame = [tx_frame; pilot_tx];
            pilot_pos(g+1) = sym_idx;

            block_syms = min(K, n_data_syms - data_count);
            for s = 1:block_syms
                sym_idx = sym_idx + 1;
                data_sym_pos(data_count + s) = sym_idx;
                idx = data_count + s;
                syms = all_mod_syms((idx-1)*cfg.N_active+1 : idx*cfg.N_active);
                tx_frame = [tx_frame; ofdm_tx_symbol(syms, cfg)];
            end
            data_count = data_count + block_syms;
            if data_count >= n_data_syms, break; end
        end

        cfg.pilot_positions = pilot_pos(1:g+1);
        cfg.data_sym_pos = data_sym_pos;
    end

    cfg.train_syms = train_syms;
    cfg.pilot_syms = pilot_syms;
    cfg.train_tx   = train_tx;
    cfg.pilot_tx   = pilot_tx;
    cfg.n_data_syms = n_data_syms;
    cfg.bits_per_ofdm_sym = bits_per_ofdm_sym;
    cfg.pilot_spacing = pilot_spacing;

    n_pilots = length(cfg.pilot_positions);
    fprintf('\n===== OFDM Frame =====\n');
    fprintf('Modulation:       %s (%d bit/sym)\n', mod_type, bpsym);
    fprintf('Coded bits:       %d\n', length(coded_bits));
    fprintf('Data symbols:     %d (padded to %d bits)\n', n_data_syms, padded_len);
    fprintf('Pilots:           %d (periodic, spacing=%s)\n', n_pilots, ...
            ternary(isinf(pilot_spacing), 'single', sprintf('%d syms', pilot_spacing)));
    fprintf('Total frame:      %d samples (%.1f ms)\n', length(tx_frame), length(tx_frame)/1e3);
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
