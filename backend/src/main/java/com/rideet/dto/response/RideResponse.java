package com.rideet.dto.response;

import com.rideet.domain.enums.PaymentMethod;
import com.rideet.domain.enums.RideStatus;
import com.rideet.domain.enums.VehicleType;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class RideResponse {
    private Long id;
    private Long passengerId;
    private String passengerName;
    private Long driverId;
    private String driverName;
    private String driverPhone;
    private String driverProfilePicture;
    private Double driverRating;
    private String vehicleMake;
    private String vehicleModel;
    private String licensePlate;
    private String vehicleColor;

    private String pickupAddress;
    private Double pickupLatitude;
    private Double pickupLongitude;
    private String destinationAddress;
    private Double destinationLatitude;
    private Double destinationLongitude;

    private VehicleType vehicleType;
    private RideStatus status;

    private Double estimatedFare;
    private Double actualFare;
    private Double distanceKm;
    private Integer durationMinutes;

    private PaymentMethod paymentMethod;

    private LocalDateTime requestedAt;
    private LocalDateTime driverAssignedAt;
    private LocalDateTime startedAt;
    private LocalDateTime completedAt;
}
