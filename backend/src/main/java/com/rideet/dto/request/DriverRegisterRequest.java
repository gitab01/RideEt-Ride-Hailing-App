package com.rideet.dto.request;

import com.rideet.domain.enums.VehicleType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

/**
 * A driver's vehicle details, submitted once against an already-registered user account.
 */
@Getter
@Setter
public class DriverRegisterRequest {

    @NotBlank
    private String vehicleMake;

    @NotBlank
    private String vehicleModel;

    @NotBlank
    private String vehicleYear;

    @NotBlank
    private String licensePlate;

    @NotBlank
    private String vehicleColor;

    @NotNull
    private VehicleType vehicleType;
}
