package com.rideet.dto.response;

import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.VehicleType;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

/**
 * Driver view for the driver app and the admin dashboard.
 *
 * <p>The entity cannot be returned directly: {@code user} is a lazy association and
 * {@code open-in-view} is off, so serialising it throws once the session is closed.
 */
@Getter
@Builder
public class DriverResponse {

    private Long id;
    private Long userId;
    private String fullName;
    private String phone;
    private String email;

    private String vehicleMake;
    private String vehicleModel;
    private String vehicleYear;
    private String licensePlate;
    private String vehicleColor;
    private VehicleType vehicleType;

    private String driverLicenseUrl;
    private String vehicleRegistrationUrl;
    private String insuranceUrl;

    private DriverStatus status;
    private boolean documentsVerified;
    private String verificationNote;
    private Integer offersAccepted;
    private Integer offersDeclined;
    private Double currentLatitude;
    private Double currentLongitude;
    private LocalDateTime lastLocationUpdate;

    private Double rating;
    private Integer totalRatings;
    private Integer totalRides;
    private Double totalEarnings;
    private Boolean enabled;
    private LocalDateTime createdAt;
}
