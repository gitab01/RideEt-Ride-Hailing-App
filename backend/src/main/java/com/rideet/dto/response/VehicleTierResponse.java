package com.rideet.dto.response;

import com.rideet.domain.enums.VehicleType;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * A row of the fare table as the admin console edits it. The vehicle type is included so the
 * client can send the whole list back with one PUT per tier without keeping the key locally.
 */
@Data
@Builder
public class VehicleTierResponse {
    private Long id;
    private VehicleType vehicleType;
    private String displayName;
    private Double baseFare;
    private Double perKmRate;
    private Double perMinuteRate;
    private Double bookingFee;
    private Double minimumFare;
    private Double surgeMultiplier;
    private boolean active;
    private LocalDateTime updatedAt;

    /** What a 10 km / 20 minute trip would cost at these numbers — the operator's sanity check. */
    private Double sampleFare10km;
}
