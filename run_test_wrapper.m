function run_test_wrapper(use_mimo, snr_val, N_val)
% Wrapper to call test_all or test_all_mimo from GUI.
% Passes parameters via temporary file (survives clear/clc in scripts).
    N = N_val;  %#ok<NASGU>
    save('gui_params.mat', 'snr_val', 'N');
    if use_mimo
        test_all_mimo;
    else
        test_all;
    end
end
