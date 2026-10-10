package com.rideet.dto.response;

import com.rideet.domain.enums.UserRole;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * Account view for the admin dashboard. Deliberately has no password field: the entity's
 * own hash must never reach an admin list payload.
 */
@Data
@Builder
public class UserResponse {

    private Long id;
    private String firstName;
    private String lastName;
    private String fullName;
    private String email;
    private String phone;
    private UserRole role;
    private String profilePictureUrl;
    private Double rating;
    private Integer totalRatings;
    private Double walletBalance;
    private boolean enabled;
    private LocalDateTime createdAt;
}
