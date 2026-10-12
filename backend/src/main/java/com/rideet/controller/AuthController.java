package com.rideet.controller;

import com.rideet.domain.entity.User;
import com.rideet.dto.request.LoginRequest;
import com.rideet.dto.request.OtpSendRequest;
import com.rideet.dto.request.OtpVerifyRequest;
import com.rideet.dto.request.PasswordResetRequest;
import com.rideet.dto.request.RegisterRequest;
import com.rideet.dto.response.ApiResponse;
import com.rideet.dto.response.AuthResponse;
import com.rideet.dto.response.OtpChallengeResponse;
import com.rideet.dto.response.UserResponse;
import com.rideet.mapper.UserViewMapper;
import com.rideet.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final UserViewMapper userViewMapper;

    @PostMapping("/register")
    public ResponseEntity<ApiResponse<AuthResponse>> register(@Valid @RequestBody RegisterRequest request) {
        AuthResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success("Registration successful", response));
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthResponse>> login(@Valid @RequestBody LoginRequest request) {
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(ApiResponse.success("Login successful", response));
    }

    /** Asks for a one-time code for an existing account's phone number. */
    @PostMapping("/otp/send")
    public ResponseEntity<ApiResponse<OtpChallengeResponse>> sendOtp(@Valid @RequestBody OtpSendRequest request) {
        return ResponseEntity.ok(ApiResponse.success("Code sent", authService.sendLoginOtp(request.getPhone())));
    }

    /** Exchanges a code for the same token pair a password login returns. */
    @PostMapping("/otp/verify")
    public ResponseEntity<ApiResponse<AuthResponse>> verifyOtp(@Valid @RequestBody OtpVerifyRequest request) {
        AuthResponse response = authService.loginWithOtp(request.getPhone(), request.getCode());
        return ResponseEntity.ok(ApiResponse.success("Login successful", response));
    }

    /** Asks for a reset code on an account the caller already owns. */
    @PostMapping("/password-reset/send")
    public ResponseEntity<ApiResponse<OtpChallengeResponse>> sendPasswordReset(
            @Valid @RequestBody OtpSendRequest request) {
        return ResponseEntity.ok(
                ApiResponse.success("Code sent", authService.sendPasswordResetOtp(request.getPhone())));
    }

    /** Sets a new password; the caller signs in with it afterwards. */
    @PostMapping("/password-reset/confirm")
    public ResponseEntity<ApiResponse<Void>> confirmPasswordReset(
            @Valid @RequestBody PasswordResetRequest request) {
        authService.resetPassword(request.getPhone(), request.getCode(), request.getNewPassword());
        return ResponseEntity.ok(ApiResponse.success("Password updated", null));
    }

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthResponse>> refreshToken(@RequestParam String refreshToken) {
        AuthResponse response = authService.refreshToken(refreshToken);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /** Account behind the presented token, for an app that resumed from stored auth. */
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserResponse>> me(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(ApiResponse.success(userViewMapper.toResponse(user)));
    }
}
