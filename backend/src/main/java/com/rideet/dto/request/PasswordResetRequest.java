package com.rideet.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

/** Completes a password reset: the code that was sent to the number, plus the new password. */
@Data
public class PasswordResetRequest {

    @NotBlank
    @Pattern(regexp = "\\+[0-9]{9,15}", message = "Phone must be in international format, e.g. +251911000001")
    private String phone;

    @NotBlank
    @Pattern(regexp = "[0-9]{4,8}", message = "The code is 4 to 8 digits")
    private String code;

    @NotBlank
    @Size(min = 8, message = "Password must be at least 8 characters")
    private String newPassword;
}
