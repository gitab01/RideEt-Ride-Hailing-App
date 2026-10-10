package com.rideet.dto.response;

import com.rideet.domain.enums.VehicleType;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

/**
 * An offer pushed to one driver. Carries everything needed to decide without a
 * second round-trip, plus the deadline the countdown is drawn from.
 */
@Getter
@Builder
public class RideOfferResponse {

    private Long rideId;
    private Long passengerId;
    private String passengerName;

    private String pickupAddress;
    private Double pickupLatitude;
    private Double pickupLongitude;
    private String destinationAddress;
    private Double destinationLatitude;
    private Double destinationLongitude;

    private VehicleType vehicleType;
    private Double estimatedFare;
    private Double distanceToPickupKm;
    private Integer durationMinutes;

    /** When the offer stops being acceptable; the client renders the countdown from it. */
    private LocalDateTime expiresAt;
    private Integer offerWindowSeconds;
}
