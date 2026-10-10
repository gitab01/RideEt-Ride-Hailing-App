package com.rideet.domain.entity;

import com.rideet.domain.enums.RideStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Append-only history of every ride state transition, so a dispute can be
 * reconstructed from the row set rather than trusting a client's recollection.
 */
@Entity
@Table(name = "ride_events", indexes = @Index(name = "idx_ride_events_ride", columnList = "ride_id, created_at"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RideEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "ride_id", nullable = false)
    private Ride ride;

    @Enumerated(EnumType.STRING)
    @Column(length = 32)
    private RideStatus fromStatus;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private RideStatus toStatus;

    /** PASSENGER, DRIVER or SYSTEM. */
    @Column(nullable = false, length = 16)
    private String actor;

    private String note;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
