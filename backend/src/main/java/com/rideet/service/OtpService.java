package com.rideet.service;

import com.rideet.domain.entity.OtpVerification;
import com.rideet.exception.BadRequestException;
import com.rideet.repository.OtpRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class OtpService {

    private final OtpRepository otpRepository;

    @Value("${otp.expiration-minutes:5}")
    private int expirationMinutes;

    @Value("${otp.length:6}")
    private int codeLength;

    /**
     * With no SMS gateway wired up, a dev-profile build accepts this one code for any number so
     * the apps can be exercised end to end. Off by default; only the dev profile turns it on.
     */
    @Value("${otp.dev-mode:false}")
    private boolean devMode;

    @Value("${otp.dev-code:}")
    private String devCode;

    public int expirationSeconds() {
        return expirationMinutes * 60;
    }

    /** The code that dev mode accepts, or null when real codes are the only way in. */
    public String activeDevCode() {
        return devMode && devCode != null && !devCode.isBlank() ? devCode : null;
    }

    @Transactional
    public String generateOtp(String identifier, String purpose) {
        otpRepository.invalidateAllForIdentifierAndPurpose(identifier, purpose);

        String code = randomCode();

        OtpVerification otp = OtpVerification.builder()
                .identifier(identifier)
                .otpCode(code)
                .purpose(purpose)
                .expiresAt(LocalDateTime.now().plusMinutes(expirationMinutes))
                .build();

        otpRepository.save(otp);
        // There is no SMS provider configured, so the code only reaches the log. A gateway
        // (Twilio et al) belongs here; until then this is the single place that changes.
        log.info("OTP generated for {} ({}): {}", identifier, purpose, code);
        return code;
    }

    @Transactional
    public boolean verifyOtp(String identifier, String code, String purpose) {
        if (activeDevCode() != null && activeDevCode().equals(code)) {
            log.warn("Dev-mode OTP accepted for {} ({}) — otp.dev-mode must be off outside development",
                    identifier, purpose);
            return true;
        }

        OtpVerification otp = otpRepository
                .findTopByIdentifierAndPurposeAndUsedFalseOrderByCreatedAtDesc(identifier, purpose)
                .orElseThrow(() -> new BadRequestException("OTP not found or already used"));

        if (otp.isExpired()) {
            throw new BadRequestException("OTP has expired");
        }
        if (!otp.getOtpCode().equals(code)) {
            throw new BadRequestException("Invalid OTP");
        }

        otp.setUsed(true);
        otpRepository.save(otp);
        return true;
    }

    private String randomCode() {
        SecureRandom random = new SecureRandom();
        StringBuilder sb = new StringBuilder(codeLength);
        for (int i = 0; i < codeLength; i++) {
            sb.append(random.nextInt(10));
        }
        return sb.toString();
    }

    /** How long the most recent unused code for this identifier still has, for the app's timer. */
    @Transactional(readOnly = true)
    public long secondsLeft(String identifier, String purpose) {
        return otpRepository
                .findTopByIdentifierAndPurposeAndUsedFalseOrderByCreatedAtDesc(identifier, purpose)
                .map(o -> Math.max(0, Duration.between(LocalDateTime.now(), o.getExpiresAt()).getSeconds()))
                .orElse((long) expirationSeconds());
    }
}
