package com.rideet.domain.entity;

import com.rideet.domain.enums.VehicleType;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * One row per service tier, so an operator can price Classic differently from XL without a
 * redeploy. The values here are the only fare inputs the quoting path uses; the {@code fare.*}
 * settings exist solely to seed this table on a blank database.
 */
@Entity
@Table(name = "vehicle_tiers")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VehicleTier {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, unique = true, length = 20)
    private VehicleType vehicleType;

    /** What the rider sees on the option card, e.g. "Classic". */
    @Column(nullable = false, length = 40)
    private String displayName;

    @Column(nullable = false)
    private double baseFare;

    @Column(nullable = false)
    private double perKmRate;

    @Column(nullable = false)
    private double perMinuteRate;

    @Column(nullable = false)
    private double bookingFee;

    @Column(nullable = false)
    private double minimumFare;

    @Column(nullable = false)
    private double surgeMultiplier;

    /** A disabled tier stops being offered but keeps its history for past rides. */
    @Builder.Default
    private boolean active = true;

    private LocalDateTime updatedAt;

    @PrePersist
    @PreUpdate
    void touch() {
        updatedAt = LocalDateTime.now();
    }

    /**
     * Distance and time make up the trip; the booking fee and the floor are added after surge so
     * a surge period cannot inflate a fee that is not tied to demand.
     */
    public double fareFor(double distanceKm, int durationMinutes) {
        double trip = (baseFare + distanceKm * perKmRate + durationMinutes * perMinuteRate) * surgeMultiplier;
        return round2(Math.max(trip + bookingFee, minimumFare));
    }

    public double distanceFareFor(double distanceKm) {
        return round2(distanceKm * perKmRate * surgeMultiplier);
    }

    public double timeFareFor(int durationMinutes) {
        return round2(durationMinutes * perMinuteRate * surgeMultiplier);
    }

    public double baseFareComponent() {
        return round2(baseFare * surgeMultiplier);
    }

    private static double round2(double v) {
        return Math.round(v * 100.0) / 100.0;
    }
}
