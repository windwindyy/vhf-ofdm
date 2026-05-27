function main()
% VHF OFDM Communication System — Main Entry Point
% Group 2: 100 MHz carrier, 1 MHz BW, military vehicular channel (60 km/h)
%
% Select SISO or MIMO 2x2 Alamouti mode to run the full simulation.

    fprintf('=============================================================\n');
    fprintf('  VHF OFDM Communication System Simulator — Group 2\n');
    fprintf('  Carrier: 100 MHz | BW: 1 MHz | Speed: 60 km/h\n');
    fprintf('  Channel: 5-path military vehicular (fd = 5.56 Hz)\n');
    fprintf('=============================================================\n\n');

    fprintf('Select simulation mode:\n');
    fprintf('  [1] SISO  — Single-antenna OFDM system\n');
    fprintf('  [2] MIMO  — 2x2 Alamouti STBC OFDM system\n');
    fprintf('  [3] GUI   — Interactive application\n');
    fprintf('  [0] Exit\n\n');

    choice = input('Enter choice (0-3): ');

    switch choice
        case 1
            fprintf('\n>>> Running SISO simulation...\n\n');
            test_all;

        case 2
            fprintf('\n>>> Running MIMO 2x2 Alamouti simulation...\n\n');
            test_all_mimo;

        case 3
            fprintf('\n>>> Launching GUI...\n');
            vhf_ofdm_app;

        case 0
            fprintf('Exiting.\n');
            return;

        otherwise
            fprintf('Invalid choice. Exiting.\n');
            return;
    end

    fprintf('\n===== Simulation Complete =====\n');
end
