package com.rideet.dto.response;

import com.rideet.domain.enums.UserRole;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AuthResponse {
    private String accessToken;
    private String refreshToken;
    private String tokenType;
    private Long userId;
    private String email;
    private String firstName;
    private String lastName;
    private UserRole role;
    private String profilePictureUrl;
    /** False for a DRIVER account that has not filed vehicle details yet. */
    @Builder.Default
    private boolean driverOnboarded = true;
}
