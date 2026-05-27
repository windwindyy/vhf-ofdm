function [s1_hat, s2_hat] = alamouti_decode(Y1_t1, Y1_t2, Y2_t1, Y2_t2, H)
% Alamouti combining for 2×2 MIMO, per subcarrier
%   Y1_t1, Y1_t2 - RX1 received symbols in two time slots (400×1 each)
%   Y2_t1, Y2_t2 - RX2 received symbols in two time slots (400×1 each)
%   H  - struct with fields .h11, .h12, .h21, .h22 (400×1 each)
%   s1_hat, s2_hat - combined symbol estimates (400×1 each)
%
% Alamouti scheme per subcarrier k:
%   Slot 1: y1=h11*s1 + h12*s2,     y2=h21*s1 + h22*s2
%   Slot 2: y1=-h11*s2* + h12*s1*,  y2=-h21*s2* + h22*s1*
%
%   s1_hat = h11'*y11 + h21'*y21 + h12*y12' + h22*y22'
%   s2_hat = h12'*y11 + h22'*y21 - h11*y12' - h21*y22'

    h11 = H.h11(:);
    h12 = H.h12(:);
    h21 = H.h21(:);
    h22 = H.h22(:);

    y11 = Y1_t1(:);
    y12 = Y1_t2(:);
    y21 = Y2_t1(:);
    y22 = Y2_t2(:);

    % Alamouti combining (conj dot products)
    s1_hat = conj(h11).*y11 + conj(h21).*y21 + h12.*conj(y12) + h22.*conj(y22);
    s2_hat = conj(h12).*y11 + conj(h22).*y21 - h11.*conj(y12) - h21.*conj(y22);

    % Channel gain normalization (optional, preserves constellation scale)
    gain = abs(h11).^2 + abs(h21).^2 + abs(h12).^2 + abs(h22).^2;
    s1_hat = s1_hat ./ gain;
    s2_hat = s2_hat ./ gain;

    fprintf('Alamouti decode: 2×2 combining, avg gain=%.2f (4-branch diversity)\n', ...
            mean(gain));
end
