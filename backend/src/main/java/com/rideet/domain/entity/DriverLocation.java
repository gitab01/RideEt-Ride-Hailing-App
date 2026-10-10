package com.rideet.domain.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * One point of a driver's position trail. High-frequency pings are buffered in
 * memory and batch-written here, so this table is history for audits and replay,
 * never the source used for matching.
 */
@Entity
@Table(name = "driver_locations",
        indexes = @Index(name = "idx_driver_locations_driver_time", columnList = "driver_id, recorded_at"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DriverLocation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Plain id, not an association: rows are written in bulk and read by driver. */
    @Column(name = "driver_id", nullable = false)
    private Long driverId;

    @Column(nullable = false)
    private Double latitude;

    @Column(nullable = false)
    private Double longitude;

    private Double heading;

    private Double speedKmh;

    @Column(nullable = false)
    private LocalDateTime recordedAt;
}
