package com.rideet.dto.response;

import com.rideet.domain.enums.VehicleType;
import lombok.Builder;
import lombok.Data;

/**
 * One row of the vehicle picker: what this tier costs for the requested trip and how far the
 * nearest car of that tier is. {@code pickupEtaMinutes} is null when no online driver of the
 * tier is inside the search radius, which the apps show as "no cars nearby" rather than a guess.
 */
@Data
@Builder
public class RideOptionResponse {
    private VehicleType vehicleType;
    private String displayName;
    private Double estimatedFare;
    private Double distanceKm;
    private Integer durationMinutes;
    private Double surgeMultiplier;
    private Integer pickupEtaMinutes;
    private Double distanceToNearestKm;
    private Integer driversAvailable;
}
