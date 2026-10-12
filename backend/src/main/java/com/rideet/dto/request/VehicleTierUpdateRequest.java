package com.rideet.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * One editable row of the fare table. The vehicle type itself is not part of this payload —
 * it is the key, and re-keying a tier would rewrite the pricing of past rides.
 */
@Data
public class VehicleTierUpdateRequest {

    @NotBlank
    @Size(max = 40)
    private String displayName;

    @NotNull @DecimalMin("0.0")
    private Double baseFare;

    @NotNull @DecimalMin("0.0")
    private Double perKmRate;

    @NotNull @DecimalMin("0.0")
    private Double perMinuteRate;

    @NotNull @DecimalMin("0.0")
    private Double bookingFee;

    @NotNull @DecimalMin("0.0")
    private Double minimumFare;

    /** 1.0 means no surge. Below that a tier would be priced under its own cost. */
    @NotNull @DecimalMin("1.0")
    private Double surgeMultiplier;

    @NotNull
    private Boolean active;
}
