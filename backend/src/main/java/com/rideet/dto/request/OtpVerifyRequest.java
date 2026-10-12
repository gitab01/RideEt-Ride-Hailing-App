package com.rideet.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class OtpVerifyRequest {

    @NotBlank
    @Pattern(regexp = "\\+[0-9]{9,15}", message = "Phone must be in international format, e.g. +251911000001")
    private String phone;

    @NotBlank
    @Pattern(regexp = "[0-9]{4,8}", message = "The code is 4 to 8 digits")
    private String code;
}
