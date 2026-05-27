function X_eq = channel_equalize(Y_data, H_est, method, sigma2)
% Channel equalization for one OFDM data symbol
%   Y_data  - 400×1 received symbols on active subcarriers
%   H_est   - 400×1 estimated channel frequency response
%   method  - 'ZF' (default) or 'MMSE'
%   sigma2  - noise variance (required only for MMSE)
%   X_eq    - 400×1 equalized symbols

    if nargin < 3 || isempty(method)
        method = 'ZF';
    end

    switch upper(method)
        case 'ZF'
            X_eq = Y_data(:) ./ H_est(:);

        case 'MMSE'
            if nargin < 4 || isempty(sigma2)
                error('MMSE equalization requires sigma2 (noise variance)');
            end
            H = H_est(:);
            % X_mmse = Y * conj(H) / (|H|^2 + sigma2)
            X_eq = Y_data(:) .* conj(H) ./ (abs(H).^2 + sigma2);

        otherwise
            error('Unknown equalization method: %s. Use ZF or MMSE', method);
    end
end
