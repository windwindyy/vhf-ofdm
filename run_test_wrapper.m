function run_test_wrapper(use_mimo, snr_val, N_val)
% Wrapper to call main() from GUI with parameter override.
    if use_mimo
        main('mimo', snr_val, N_val);
    else
        main('siso', snr_val, N_val);
    end
end
