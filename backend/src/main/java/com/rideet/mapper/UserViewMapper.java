package com.rideet.mapper;

import com.rideet.domain.entity.User;
import com.rideet.dto.response.UserResponse;
import org.springframework.stereotype.Component;

/**
 * Account view used by both the admin directory and a signed-in user's own profile call.
 * There is deliberately no password field, so no caller can serialize the hash by accident.
 */
@Component
public class UserViewMapper {

    public UserResponse toResponse(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .firstName(user.getFirstName())
                .lastName(user.getLastName())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .role(user.getRole())
                .profilePictureUrl(user.getProfilePictureUrl())
                .rating(user.getRating())
                .totalRatings(user.getTotalRatings())
                .walletBalance(user.getWalletBalance())
                .enabled(user.isEnabled())
                .createdAt(user.getCreatedAt())
                .build();
    }
}
