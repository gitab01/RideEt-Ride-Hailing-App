package com.rideet.dto.request;

import jakarta.validation.constraints.Email;
import lombok.Data;

/**
 * Email or phone — exactly one of the two must be present. Which one is accepted depends on
 * how the account was created, and the phone form is what both mobile apps show.
 */
@Data
public class LoginRequest {

    @Email
    private String email;

    private String phone;

    private String password;
}
