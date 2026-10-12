package com.rideet.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class OtpSendRequest {

    @NotBlank
    @Pattern(regexp = "\\+[0-9]{9,15}", message = "Phone must be in international format, e.g. +251911000001")
    private String phone;
}
