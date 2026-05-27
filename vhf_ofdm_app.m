function vhf_ofdm_app()
% VHF OFDM System Simulator GUI — Group 2
% Supports SISO and MIMO 2×2 Alamouti.

    fig = uifigure('Name', 'VHF OFDM Simulator — Group 2', ...
                   'Position', [50 40 1280 780], 'Resize', 'on');

    main_grid = uigridlayout(fig, [1 2]);
    main_grid.ColumnWidth = {260, '1x'};
    main_grid.Padding = [5 5 5 5];

    % ===== LEFT PANEL =====
    left = uigridlayout(main_grid, [24 2]);
    left.Layout.Row = 1;  left.Layout.Column = 1;
    left.RowHeight = repmat({22}, 1, 24);
    left.ColumnWidth = {100, '1x'};
    left.Padding = [8 8 8 8];
    left.Scrollable = 'on';

    ri = 1;
    uilabel(left, 'Text', 'Antenna Mode:', 'HorizontalAlignment', 'right');
    mode_dd = uidropdown(left, 'Items', {'SISO', '2x2 MIMO'}, 'Value', 'SISO');
    mode_dd.Layout.Row = ri;  mode_dd.Layout.Column = 2;  ri = ri+1;

    uilabel(left, 'Text', 'Source Bits:', 'HorizontalAlignment', 'right');
    N_edit = uieditfield(left, 'numeric', 'Value', 100000, 'Limits', [1000 1e7], 'HorizontalAlignment', 'right');
    N_edit.Layout.Row = ri;  N_edit.Layout.Column = 2;  ri = ri+1;

    uilabel(left, 'Text', 'Modulation:', 'HorizontalAlignment', 'right');
    mod_dd = uidropdown(left, 'Items', {'QPSK', '16QAM', '64QAM'}, 'Value', 'QPSK');
    mod_dd.Layout.Row = ri;  mod_dd.Layout.Column = 2;  ri = ri+1;

    uilabel(left, 'Text', 'SNR Start (dB):', 'HorizontalAlignment', 'right');
    snr_start_edit = uieditfield(left, 'numeric', 'Value', 0, 'Limits', [-10 40], 'HorizontalAlignment', 'right');
    snr_start_edit.Layout.Row = ri;  snr_start_edit.Layout.Column = 2;  ri = ri+1;

    uilabel(left, 'Text', 'SNR End (dB):', 'HorizontalAlignment', 'right');
    snr_end_edit = uieditfield(left, 'numeric', 'Value', 25, 'Limits', [-10 40], 'HorizontalAlignment', 'right');
    snr_end_edit.Layout.Row = ri;  snr_end_edit.Layout.Column = 2;  ri = ri+1;

    uilabel(left, 'Text', 'SNR Step (dB):', 'HorizontalAlignment', 'right');
    snr_step_edit = uieditfield(left, 'numeric', 'Value', 5, 'Limits', [0.5 10], 'HorizontalAlignment', 'right');
    snr_step_edit.Layout.Row = ri;  snr_step_edit.Layout.Column = 2;  ri = ri+1;

    uilabel(left, 'Text', 'CFO (Hz):', 'HorizontalAlignment', 'right');
    cfo_edit = uieditfield(left, 'numeric', 'Value', 10, 'Limits', [0 100], 'HorizontalAlignment', 'right');
    cfo_edit.Layout.Row = ri;  cfo_edit.Layout.Column = 2;  ri = ri+1;

    uilabel(left, 'Text', 'Equalizer:', 'HorizontalAlignment', 'right');
    eq_dd = uidropdown(left, 'Items', {'MMSE', 'ZF'}, 'Value', 'MMSE');
    eq_dd.Layout.Row = ri;  eq_dd.Layout.Column = 2;  ri = ri+1;

    uilabel(left, 'Text', 'Decision:', 'HorizontalAlignment', 'right');
    dec_dd = uidropdown(left, 'Items', {'Soft', 'Hard'}, 'Value', 'Soft');
    dec_dd.Layout.Row = ri;  dec_dd.Layout.Column = 2;  ri = ri+1;

    uilabel(left, 'Text', 'Pilot Spacing:', 'HorizontalAlignment', 'right');
    pilot_edit = uieditfield(left, 'numeric', 'Value', 40, 'Limits', [10 200], 'HorizontalAlignment', 'right');
    pilot_edit.Layout.Row = ri;  pilot_edit.Layout.Column = 2;  ri = ri+1;

    uilabel(left, 'Text', 'SNR For Test (dB):', 'HorizontalAlignment', 'right');
    snr_test_edit = uieditfield(left, 'numeric', 'Value', 5, 'Limits', [-10 40], 'HorizontalAlignment', 'right');
    snr_test_edit.Layout.Row = ri;  snr_test_edit.Layout.Column = 2;  ri = ri+1;

    ri = ri + 1;
    run_btn = uibutton(left, 'push', 'Text', "Run SNR Sweep", ...
                       'FontSize', 13, 'FontWeight', 'bold', ...
                       'BackgroundColor', [0.23 0.51 0.92], 'FontColor', 'white');
    run_btn.Layout.Row = ri;  run_btn.Layout.Column = [1 2];  ri = ri+1;

    fullviz_btn = uibutton(left, 'push', 'Text', "链路观察", ...
                           'FontSize', 13, 'FontWeight', 'bold', ...
                           'BackgroundColor', [0.85 0.33 0.10], 'FontColor', 'white');
    fullviz_btn.Layout.Row = ri;  fullviz_btn.Layout.Column = [1 2];  ri = ri+2;

    status_lbl = uilabel(left, 'Text', 'Ready.', 'FontSize', 10, 'FontColor', [0.4 0.4 0.4]);
    status_lbl.Layout.Row = ri;  status_lbl.Layout.Column = [1 2];  ri = ri+2;

    result_area = uitextarea(left, 'Value', '', 'FontSize', 10, 'Editable', 'off');
    result_area.Layout.Row = [ri ri+6];  result_area.Layout.Column = [1 2];

    % ===== RIGHT PANEL: BER Curve only =====
    right_grid = uigridlayout(main_grid, [1 1]);
    right_grid.Layout.Row = 1;  right_grid.Layout.Column = 2;

    tab_group = uitabgroup(right_grid);
    tab_group.Layout.Row = 1;  tab_group.Layout.Column = 1;

    % --- Tab 0: BER Curve (SNR Sweep) ---
    tab_ber = uitab(tab_group, 'Title', 'BER Curve');
    ber_grid = uigridlayout(tab_ber, [2 1]);
    ber_grid.RowHeight = {'1x', '1x'};
    ax_ber = uiaxes(ber_grid);
    ax_ber.Layout.Row = 1;  ax_ber.Layout.Column = 1;
    ax_fer = uiaxes(ber_grid);
    ax_fer.Layout.Row = 2;  ax_fer.Layout.Column = 1;

    % --- Fixed tabs for link observation (pre-created, shared by SISO & MIMO) ---
    link_tab_names = {'信源编码交织', '信道', '符号调制', 'OFDM时频域', ...
                      '时间频率同步', '信道估计', '均衡与星座', '误码率统计'};
    link_tabs = cell(1, length(link_tab_names));
    % Store handles: each tab gets its grid + stored axes list (to be created on demand)
    for k = 1:length(link_tab_names)
        t = uitab(tab_group, 'Title', link_tab_names{k});
        link_tabs{k} = t;
    end

    % Helper: clear a tab and create fresh grid+axes
    function new_axes = reset_tab(tab, n_rows, n_cols)
        delete(tab.Children);
        g = uigridlayout(tab, [n_rows n_cols]);
        g.Padding = [5 5 5 5];
        new_axes = gobjects(n_rows, n_cols);
        for rr = 1:n_rows
            for cc = 1:n_cols
                ax = uiaxes(g);
                ax.Layout.Row = rr;  ax.Layout.Column = cc;
                new_axes(rr, cc) = ax;
            end
        end
    end

    % Helper: copy subplot content from a figure to a tab
    function copy_fig_to_axes(fig_num, axes_grid)
        if ~ishandle(fig_num), return; end
        src_axes = findobj(fig_num, 'Type', 'axes');
        n = length(src_axes);
        if n == 0, return; end
        % Sort source axes top-to-bottom
        pos = zeros(n,4);
        for i=1:n, p=get(src_axes(i),'Position'); pos(i,:)=p; end
        [~, idx] = sortrows(pos, [-2 1]);
        src_axes = src_axes(idx);
        % Flatten destination axes grid
        dst_list = axes_grid(:);
        n_copy = min(n, length(dst_list));
        for i = 1:n_copy
            src = src_axes(i);
            dst = dst_list(i);
            chil = get(src, 'Children');
            if ~isempty(chil), copyobj(chil, dst); end
            try dst.XLabel.String = get(get(src,'XLabel'),'String'); catch, end
            try dst.YLabel.String = get(get(src,'YLabel'),'String'); catch, end
            try dst.Title.String  = get(get(src,'Title'),'String'); catch, end
            try dst.XLim = get(src,'XLim'); catch, end
            try dst.YLim = get(src,'YLim'); catch, end
            try dst.XScale = get(src,'XScale'); catch, end
            try dst.YScale = get(src,'YScale'); catch, end
            try
                l = get(src,'Legend');
                if ~isempty(l), legend(dst, l.String, 'Location', l.Location); end
            catch, end
            grid(dst, 'on');
        end
    end

    % ===== SIMULATION CALLBACK =====
    function run_simulation()
        status_lbl.Text = 'Building TX chain...';  drawnow;

        use_mimo = contains(mode_dd.Value, 'MIMO');
        N     = N_edit.Value;
        mod_t = mod_dd.Value;
        snr_v = snr_start_edit.Value : snr_step_edit.Value : snr_end_edit.Value;
        cfo   = cfo_edit.Value;
        eq_m  = eq_dd.Value;
        dec_t = dec_dd.Value;
        p_sp  = pilot_edit.Value;
        f_len = 1024;
        n_snr = length(snr_v);

        ber_v = zeros(1, n_snr);
        fer_v = zeros(1, n_snr);

        bits = generate_source(N);
        tx_b = crc16_encode(bits, f_len);
        coded = channel_encode(tx_b);
        [int_b, perm] = interleave(coded);

        if use_mimo
            [tx1, tx2, cfg] = mimo_ofdm_assemble_frame(int_b, mod_t, p_sp);
        else
            [tx_f, cfg] = ofdm_assemble_frame(int_b, mod_t, p_sp);
        end

        for i = 1:n_snr
            snr_db = snr_v(i);
            status_lbl.Text = sprintf('SNR %.0f dB (%d/%d)...', snr_db, i, n_snr);  drawnow;

            if use_mimo
                [rx1, rx2] = mimo_channel(tx1, tx2);
                fs_rx = 1e6;  rx_p = (mean(abs(rx1).^2)+mean(abs(rx2).^2))/2;
                if cfo~=0
                    t1=(0:length(rx1)-1)'/fs_rx; t2=(0:length(rx2)-1)'/fs_rx;
                    rx1=rx1.*exp(1j*2*pi*cfo*t1); rx2=rx2.*exp(1j*2*pi*cfo*t2);
                end
                rx1=add_awgn(rx1,snr_db); rx2=add_awgn(rx2,snr_db);
                [rx1s,rx2s,fs1,~]=ofdm_mimo_sync(rx1,rx2,cfg);
                Hd=mimo_channel_est(rx1s,rx2s,cfg,fs1);
                n_p=cfg.n_data_pairs; dp=cfg.data_sym_pos; Xa=[];
                for p=1:n_p
                    d1=2*p-1; d2=2*p;
                    s1=fs1+dp(d1)*cfg.sym_len; s2=fs1+dp(d2)*cfg.sym_len;
                    if s2+cfg.sym_len-1>min(length(rx1s),length(rx2s)), break; end
                    t1_1=ofdm_rx_demod(rx1s(s1:s1+cfg.sym_len-1),cfg);
                    t1_2=ofdm_rx_demod(rx1s(s2:s2+cfg.sym_len-1),cfg);
                    t2_1=ofdm_rx_demod(rx2s(s1:s1+cfg.sym_len-1),cfg);
                    t2_2=ofdm_rx_demod(rx2s(s2:s2+cfg.sym_len-1),cfg);
                    [sh1,sh2]=alamouti_decode(t1_1,t1_2,t2_1,t2_2,Hd(d1));
                    Xa=[Xa;sh1;sh2];
                end
                Xa=Xa(1:ceil(length(int_b)/app_bpsym(mod_t)));
            else
                [rx_s, ~] = vhf_channel(tx_f);
                fs_rx=1e6; rx_p=mean(abs(rx_s).^2);
                if cfo~=0, tv=(0:length(rx_s)-1)'/fs_rx; rx_s=rx_s.*exp(1j*2*pi*cfo*tv); end
                rx_s=add_awgn(rx_s,snr_db);
                fs_s=ofdm_time_sync(rx_s,cfg);
                [rx_sync,~]=ofdm_freq_sync(rx_s,cfg,fs_s);
                Hd=channel_estimate_interp(rx_sync,cfg,fs_s,snr_db);
                nd=cfg.n_data_syms; dp=cfg.data_sym_pos;
                s2_eq=rx_p*10^(-snr_db/10); Xa=[];
                for s=1:nd
                    ss=fs_s+dp(s)*cfg.sym_len;
                    if ss+cfg.sym_len-1>length(rx_sync), break; end
                    Ys=ofdm_rx_demod(rx_sync(ss:ss+cfg.sym_len-1),cfg);
                    Xa=[Xa; channel_equalize(Ys,Hd(:,s),eq_m,s2_eq)];
                end
                Xa=Xa(1:ceil(length(int_b)/app_bpsym(mod_t)));
            end

            if strcmp(dec_t,'Soft')
                llr=demodulate(Xa,mod_t,'soft'); llrd=deinterleave(llr,perm);
                llrd=llrd(1:length(coded)); rx_dec=channel_decode(llrd,'soft');
            else
                bh=demodulate(Xa,mod_t,'hard'); bhd=deinterleave(bh,perm);
                bhd=bhd(1:length(coded)); rx_dec=channel_decode(bhd,'hard');
            end
            [~,ber_v(i),fer_v(i)]=crc16_check(rx_dec,bits,f_len);
        end

        % Fix: replace zero BER/FER for log-scale visibility
        min_visible = 0.1 / N;
        ber_v(ber_v == 0) = min_visible;
        fer_v(fer_v == 0) = min_visible;

        % Plot BER
        cla(ax_ber);
        semilogy(ax_ber, snr_v, ber_v, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 8);
        xlabel(ax_ber, 'SNR (dB)');  ylabel(ax_ber, 'BER');
        xlim(ax_ber, [snr_v(1) snr_v(end)]);  xticks(ax_ber, snr_v);
        title(ax_ber, sprintf('BER — %s  %s  %s  %s', mode_dd.Value, mod_t, eq_m, dec_t));
        grid(ax_ber, 'on');

        % Plot FER
        cla(ax_fer);
        semilogy(ax_fer, snr_v, fer_v, 'rs-', 'LineWidth', 1.5, 'MarkerSize', 8);
        xlabel(ax_fer, 'SNR (dB)');  ylabel(ax_fer, 'FER');
        xlim(ax_fer, [snr_v(1) snr_v(end)]);  xticks(ax_fer, snr_v);
        title(ax_fer, 'FER');
        grid(ax_fer, 'on');

        result_area.Value = sprintf(['=== Complete ===\nMode: %s | Mod: %s | Eq: %s | Dec: %s\n' ...
            'SNR: %.0f~%.0f dB step=%.1f\nBest BER: %.2e | Best FER: %.3f\n' ...
            '(Values at 0 replaced by %.1e for log-scale display)'], ...
            mode_dd.Value, mod_t, eq_m, dec_t, ...
            snr_v(1), snr_v(end), snr_step_edit.Value, ...
            min(ber_v), min(fer_v), min_visible);
        status_lbl.Text = 'Ready.';
    end

    function run_full_viz()
        status_lbl.Text = 'Running link observation...';  drawnow;
        use_mimo = contains(mode_dd.Value, 'MIMO');
        close all;
        run_test_wrapper(use_mimo, snr_test_edit.Value, N_edit.Value);

        if use_mimo
            % MIMO: figures mapped to same tab names as SISO
            % Fig4=信源编码交织, Fig5=信道, Fig6=OFDM时频域, Fig7=时间频率同步
            % Fig2=信道估计, Fig1=均衡与星座, Fig3=误码率统计
            copy_fig_to_axes(4, reset_tab(link_tabs{1}, 5, 1));  % 信源编码交织
            copy_fig_to_axes(5, reset_tab(link_tabs{2}, 2, 1));  % 信道 (PDP + noisy H)
            reset_tab(link_tabs{3}, 1, 1);  % 符号调制 (skip)
            copy_fig_to_axes(6, reset_tab(link_tabs{4}, 2, 1));  % OFDM时频域
            copy_fig_to_axes(7, reset_tab(link_tabs{5}, 3, 1));  % 时间频率同步
            copy_fig_to_axes(2, reset_tab(link_tabs{6}, 2, 2));  % 信道估计
            copy_fig_to_axes(1, reset_tab(link_tabs{7}, 1, 2));  % 均衡与星座
            copy_fig_to_axes(3, reset_tab(link_tabs{8}, 1, 1));  % 误码率统计
        else
            % SISO: 8 figures
            % Fig1: Bit pipeline (5 rows)
            % Fig2: Channel PDP + envelope (2 rows)
            % Fig3: QPSK I/Q (2 rows)
            % Fig4: OFDM time+freq (2 rows)
            % Fig5: Sync (3 rows)
            % Fig6: Channel est (2 rows)
            % Fig7: Constellation (3 cols)
            % Fig8: BER/FER bar (1 row)
            fig_layouts = {5, 2, 2, 2, 3, 2, 3, 1};
            for fn = 1:8
                if ~ishandle(fn), continue; end
                n_rows = fig_layouts{fn};
                ax = reset_tab(link_tabs{fn}, n_rows, 1);
                copy_fig_to_axes(fn, ax);
                close(fn);
            end
        end
        status_lbl.Text = 'Done. Switch tabs on right.';  drawnow;
    end

    run_btn.ButtonPushedFcn = @(~,~) run_simulation();
    fullviz_btn.ButtonPushedFcn = @(~,~) run_full_viz();
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end

function b = app_bpsym(mod_type)
    switch upper(mod_type)
        case 'QPSK',  b = 2;
        case '16QAM', b = 4;
        case '64QAM', b = 6;
        otherwise,    b = 2;
    end
end
