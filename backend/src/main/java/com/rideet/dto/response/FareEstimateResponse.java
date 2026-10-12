package com.rideet.dto.response;

import com.rideet.domain.enums.VehicleType;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class FareEstimateResponse {
    private VehicleType vehicleType;
    private String displayName;
    private Double estimatedFare;
    private Double distanceKm;
    private Integer durationMinutes;
    private Double surgeMultiplier;
    private Double baseFare;
    private Double distanceFare;
    private Double timeFare;
    private Double bookingFee;
}
