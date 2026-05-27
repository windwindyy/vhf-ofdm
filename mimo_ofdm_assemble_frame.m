function [tx1, tx2, cfg] = mimo_ofdm_assemble_frame(coded_bits, mod_type, pilot_spacing)
% MIMO OFDM frame with periodic time-division pilots + Alamouti data.
%   pilot_spacing - data symbols per TX antenna between pilot groups
%                   (default Inf = single pilot group)
%
% Frame:  TX1=[Train_1|0|Pilot_1|0|D1..DK|Pilot_1|0|...]
%         TX2=[0|Train_2|0|Pilot_2|        |0|Pilot_2|...]
% Each pilot group = 2 symbols (TX1 then TX2, time-division).
% Train symbols are likewise time-division (2 symbols).

    cfg = ofdm_config();

    if nargin < 3 || isempty(pilot_spacing) || pilot_spacing <= 0
        pilot_spacing = Inf;
    end

    bpsym_map = containers.Map({'QPSK','16QAM','64QAM'}, [2, 4, 6]);
    bpsym = bpsym_map(upper(mod_type));
    bits_per_ofdm_sym = cfg.N_active * bpsym;

    % --- Generate training, pilot, data (same as before) ---
    rng(7);   train_syms_1 = 2*randi([0 1], cfg.N_active, 1) - 1;
    rng(77);  train_syms_2 = 2*randi([0 1], cfg.N_active, 1) - 1;
    rng(13);  pilot_syms_1 = 2*randi([0 1], cfg.N_active, 1) - 1;
    rng(131); pilot_syms_2 = 2*randi([0 1], cfg.N_active, 1) - 1;
    train_tx_1 = ofdm_tx_symbol(train_syms_1, cfg);
    train_tx_2 = ofdm_tx_symbol(train_syms_2, cfg);
    pilot_tx_1 = ofdm_tx_symbol(pilot_syms_1, cfg);
    pilot_tx_2 = ofdm_tx_symbol(pilot_syms_2, cfg);
    zero = zeros(cfg.sym_len, 1);

    n_data_syms = ceil(length(coded_bits) / bits_per_ofdm_sym);
    if mod(n_data_syms, 2) ~= 0, n_data_syms = n_data_syms + 1; end
    n_pairs = n_data_syms / 2;
    padded_len = n_data_syms * bits_per_ofdm_sym;
    padded_bits = zeros(1, padded_len);
    padded_bits(1:length(coded_bits)) = coded_bits;
    all_mod_syms = modulate(padded_bits, mod_type);

    % --- Build frame symbol by symbol ---
    tx1 = train_tx_1;   % sym 0
    tx2 = zero;         % sym 0

    K = pilot_spacing;
    if isinf(K)
        K = n_data_syms;  % single pilot
    end

    n_blocks = ceil(n_data_syms / K);
    n_pilot_groups = n_blocks + (isinf(pilot_spacing) == false);
    pilot_group_pos = zeros(1, n_pilot_groups);

    % sym 1: TX1 silent, TX2 training
    tx1 = [tx1; zero];
    tx2 = [tx2; train_tx_2];

    pair_idx = 0;
    data_pos_idx = 1;
    data_sym_pos = zeros(1, n_data_syms);
    for g = 1:n_pilot_groups
        pilot_group_pos(g) = length(tx1) / cfg.sym_len;

        % Insert pilot group (2 symbols)
        tx1 = [tx1; pilot_tx_1; zero];
        tx2 = [tx2; zero; pilot_tx_2];

        % Insert data block (Alamouti pairs)
        block_pairs = min(K/2, n_pairs - pair_idx);
        for p = 1:block_pairs
            idx1 = (2*pair_idx + 2*p - 2) * cfg.N_active + 1;
            idx2 = (2*pair_idx + 2*p - 1) * cfg.N_active + 1;
            s1 = all_mod_syms(idx1 : idx1 + cfg.N_active - 1);
            s2 = all_mod_syms(idx2 : idx2 + cfg.N_active - 1);

            % Slot 1: TX1→s1, TX2→s2
            tx1 = [tx1; ofdm_tx_symbol(s1, cfg)];
            tx2 = [tx2; ofdm_tx_symbol(s2, cfg)];
            data_sym_pos(data_pos_idx) = length(tx1)/cfg.sym_len - 1;
            data_pos_idx = data_pos_idx + 1;

            % Slot 2: TX1→-conj(s2), TX2→conj(s1)
            tx1 = [tx1; ofdm_tx_symbol(-conj(s2), cfg)];
            tx2 = [tx2; ofdm_tx_symbol( conj(s1), cfg)];
            data_sym_pos(data_pos_idx) = length(tx1)/cfg.sym_len - 1;
            data_pos_idx = data_pos_idx + 1;
        end
        pair_idx = pair_idx + block_pairs;
    end
    cfg.data_sym_pos = data_sym_pos;

    % Store for receiver
    cfg.train_syms_1 = train_syms_1;
    cfg.train_syms_2 = train_syms_2;
    cfg.train_tx_1   = train_tx_1;
    cfg.train_tx_2   = train_tx_2;
    cfg.pilot_syms_1 = pilot_syms_1;
    cfg.pilot_syms_2 = pilot_syms_2;
    cfg.n_data_pairs = n_pairs;
    cfg.n_data_syms  = n_data_syms;
    cfg.bits_per_ofdm_sym = bits_per_ofdm_sym;
    cfg.pilot_spacing   = pilot_spacing;
    cfg.pilot_group_pos = pilot_group_pos;

    fprintf('\n===== MIMO OFDM Frame =====\n');
    fprintf('Training: 2 symbols (time-div)\n');
    fprintf('Pilots:   %d groups × 2 (spacing=%s)\n', length(pilot_group_pos), ...
            ternary(isinf(pilot_spacing), 'single', sprintf('%d syms', pilot_spacing)));
    fprintf('Data:     %d pairs = %d OFDM symbols per antenna\n', n_pairs, n_pairs*2);
    fprintf('TX1: %d  TX2: %d samples (%.1f ms)\n', length(tx1), length(tx2), length(tx1)/1e3);
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
