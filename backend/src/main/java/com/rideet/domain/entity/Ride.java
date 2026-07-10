package com.rideet.domain.entity;

import com.rideet.domain.enums.PaymentMethod;
import com.rideet.domain.enums.RideStatus;
import com.rideet.domain.enums.VehicleType;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "rides")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Ride {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "passenger_id", nullable = false)
    private User passenger;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "driver_id")
    private Driver driver;

    // Pickup
    @Column(nullable = false)
    private String pickupAddress;

    @Column(nullable = false)
    private Double pickupLatitude;

    @Column(nullable = false)
    private Double pickupLongitude;

    // Destination
    @Column(nullable = false)
    private String destinationAddress;

    @Column(nullable = false)
    private Double destinationLatitude;

    @Column(nullable = false)
    private Double destinationLongitude;

    // Ride type
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private VehicleType vehicleType;

    // Status
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private RideStatus status = RideStatus.REQUESTED;

    // Fare
    private Double estimatedFare;
    private Double actualFare;
    private Double distanceKm;
    private Integer durationMinutes;
    private Double surgeMultiplier;

    // Payment
    @Enumerated(EnumType.STRING)
    private PaymentMethod paymentMethod;

    // Timestamps
    @Column(nullable = false, updatable = false)
    private LocalDateTime requestedAt;

    private LocalDateTime driverAssignedAt;
    private LocalDateTime driverArrivedAt;
    private LocalDateTime startedAt;
    private LocalDateTime completedAt;
    private LocalDateTime cancelledAt;

    private String cancellationReason;
    private String cancelledBy; // PASSENGER or DRIVER

    // OTP for verifying ride start
    private String rideStartOtp;

    // Ratings
    private Integer passengerRating;   // Rating given by passenger for driver
    private String passengerReview;
    private Integer driverRating;      // Rating given by driver for passenger
    private String driverReview;

    @Column(updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        requestedAt = LocalDateTime.now();
    }
}
