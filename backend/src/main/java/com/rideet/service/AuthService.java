package com.rideet.service;

import com.rideet.domain.entity.User;
import com.rideet.domain.enums.UserRole;
import com.rideet.dto.request.LoginRequest;
import com.rideet.dto.request.RegisterRequest;
import com.rideet.dto.response.AuthResponse;
import com.rideet.dto.response.OtpChallengeResponse;
import com.rideet.exception.BadRequestException;
import com.rideet.repository.DriverRepository;
import com.rideet.repository.UserRepository;
import com.rideet.security.JwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private static final String LOGIN_OTP_PURPOSE = "LOGIN";
    private static final String RESET_OTP_PURPOSE = "RESET";

    private final UserRepository userRepository;
    private final DriverRepository driverRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final OtpService otpService;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new BadRequestException("Email already registered");
        }
        if (userRepository.existsByPhone(request.getPhone())) {
            throw new BadRequestException("Phone already registered");
        }

        User user = User.builder()
                .firstName(request.getFirstName())
                .lastName(request.getLastName())
                .email(request.getEmail())
                .phone(request.getPhone())
                .password(passwordEncoder.encode(request.getPassword()))
                .role(request.getRole() != null ? request.getRole() : UserRole.PASSENGER)
                .build();

        userRepository.save(user);
        log.info("New user registered: {} ({})", user.getEmail(), user.getRole());

        String accessToken = jwtService.generateToken(user);
        String refreshToken = jwtService.generateRefreshToken(user);

        return buildAuthResponse(user, accessToken, refreshToken);
    }

    public AuthResponse login(LoginRequest request) {
        String email = resolveEmail(request);
        if (request.getPassword() == null || request.getPassword().isBlank()) {
            throw new BadRequestException("Password is required");
        }

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(email, request.getPassword())
        );

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new BadRequestException("User not found"));

        String accessToken = jwtService.generateToken(user);
        String refreshToken = jwtService.generateRefreshToken(user);

        log.info("User logged in: {}", user.getEmail());
        return buildAuthResponse(user, accessToken, refreshToken);
    }

    /** Both mobile apps collect a phone number; the account table is keyed on email. */
    private String resolveEmail(LoginRequest request) {
        boolean hasEmail = request.getEmail() != null && !request.getEmail().isBlank();
        boolean hasPhone = request.getPhone() != null && !request.getPhone().isBlank();

        if (hasEmail) return request.getEmail();
        if (hasPhone) {
            return userRepository.findByPhone(request.getPhone())
                    .orElseThrow(() -> new BadRequestException("No account found for this phone number"))
                    .getEmail();
        }
        throw new BadRequestException("Provide an email or a phone number");
    }

    /**
     * Starts a passwordless sign-in. The number must already belong to an account — creating one
     * from an OTP would let anyone claim a stranger's phone number.
     */
    @Transactional
    public OtpChallengeResponse sendLoginOtp(String phone) {
        userRepository.findByPhone(phone)
                .orElseThrow(() -> new BadRequestException("No account found for this phone number"));

        otpService.generateOtp(phone, LOGIN_OTP_PURPOSE);

        return OtpChallengeResponse.builder()
                .phone(phone)
                .expiresInSeconds((int) otpService.secondsLeft(phone, LOGIN_OTP_PURPOSE))
                .devCode(otpService.activeDevCode())
                .build();
    }

    @Transactional
    public AuthResponse loginWithOtp(String phone, String code) {
        otpService.verifyOtp(phone, code, LOGIN_OTP_PURPOSE);

        User user = userRepository.findByPhone(phone)
                .orElseThrow(() -> new BadRequestException("No account found for this phone number"));

        String accessToken = jwtService.generateToken(user);
        String refreshToken = jwtService.generateRefreshToken(user);

        log.info("User signed in with OTP: {}", user.getEmail());
        return buildAuthResponse(user, accessToken, refreshToken);
    }

    /**
     * Starts a password reset. Silently refusing an unknown number would be friendlier to the
     * account owner, but the apps need to tell the driver why nothing arrived, so it answers.
     */
    @Transactional
    public OtpChallengeResponse sendPasswordResetOtp(String phone) {
        userRepository.findByPhone(phone)
                .orElseThrow(() -> new BadRequestException("No account found for this phone number"));

        otpService.generateOtp(phone, RESET_OTP_PURPOSE);
        return OtpChallengeResponse.builder()
                .phone(phone)
                .expiresInSeconds((int) otpService.secondsLeft(phone, RESET_OTP_PURPOSE))
                .devCode(otpService.activeDevCode())
                .build();
    }

    @Transactional
    public void resetPassword(String phone, String code, String newPassword) {
        otpService.verifyOtp(phone, code, RESET_OTP_PURPOSE);

        User user = userRepository.findByPhone(phone)
                .orElseThrow(() -> new BadRequestException("No account found for this phone number"));
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
        log.info("Password reset for {}", user.getEmail());
    }

    public AuthResponse refreshToken(String refreshToken) {
        String email = jwtService.extractUsername(refreshToken);
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new BadRequestException("User not found"));

        if (!jwtService.isTokenValid(refreshToken, user)) {
            throw new BadRequestException("Invalid refresh token");
        }

        String newAccessToken = jwtService.generateToken(user);
        return buildAuthResponse(user, newAccessToken, refreshToken);
    }

    private AuthResponse buildAuthResponse(User user, String accessToken, String refreshToken) {
        boolean onboarded = user.getRole() != UserRole.DRIVER
                || driverRepository.existsByUserId(user.getId());

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .userId(user.getId())
                .email(user.getEmail())
                .firstName(user.getFirstName())
                .lastName(user.getLastName())
                .role(user.getRole())
                .profilePictureUrl(user.getProfilePictureUrl())
                .driverOnboarded(onboarded)
                .build();
    }
}
