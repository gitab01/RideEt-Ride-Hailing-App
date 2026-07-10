package com.rideet.dto.request;

import com.rideet.domain.enums.PaymentMethod;
import com.rideet.domain.enums.VehicleType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class RideRequest {

    @NotBlank
    private String pickupAddress;

    @NotNull
    private Double pickupLatitude;

    @NotNull
    private Double pickupLongitude;

    @NotBlank
    private String destinationAddress;

    @NotNull
    private Double destinationLatitude;

    @NotNull
    private Double destinationLongitude;

    @NotNull
    private VehicleType vehicleType;

    @NotNull
    private PaymentMethod paymentMethod;
}
