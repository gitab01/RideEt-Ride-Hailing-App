package com.rideet.service;

import com.rideet.domain.entity.OtpVerification;
import com.rideet.exception.BadRequestException;
import com.rideet.repository.OtpRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Random;

@Service
@RequiredArgsConstructor
@Slf4j
public class OtpService {

    private final OtpRepository otpRepository;

    @Value("${otp.expiration-minutes:5}")
    private int expirationMinutes;

    @Transactional
    public String generateOtp(String identifier, String purpose) {
        // Invalidate existing OTPs
        otpRepository.invalidateAllForIdentifierAndPurpose(identifier, purpose);

        String code = String.format("%06d", new Random().nextInt(999999));

        OtpVerification otp = OtpVerification.builder()
                .identifier(identifier)
                .otpCode(code)
                .purpose(purpose)
                .expiresAt(LocalDateTime.now().plusMinutes(expirationMinutes))
                .build();

        otpRepository.save(otp);
        log.info("OTP generated for {} ({}): {}", identifier, purpose, code);
        // TODO: Send via SMS (Twilio) or email
        return code;
    }

    @Transactional
    public boolean verifyOtp(String identifier, String code, String purpose) {
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
}
