package com.rideet.dto.response;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class OtpChallengeResponse {

    private String phone;
    private int expiresInSeconds;
    /**
     * Non-null only while {@code otp.dev-mode} is on, which is how the dev profile lets the
     * apps be exercised without an SMS gateway. A real deployment never receives this.
     */
    private String devCode;
}
