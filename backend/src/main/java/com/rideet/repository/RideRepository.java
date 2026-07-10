package com.rideet.repository;

import com.rideet.domain.entity.Ride;
import com.rideet.domain.enums.RideStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface RideRepository extends JpaRepository<Ride, Long> {

    Page<Ride> findByPassengerIdOrderByCreatedAtDesc(Long passengerId, Pageable pageable);

    Page<Ride> findByDriverIdOrderByCreatedAtDesc(Long driverId, Pageable pageable);

    Optional<Ride> findFirstByPassengerIdAndStatusIn(Long passengerId, List<RideStatus> statuses);

    Optional<Ride> findFirstByDriverIdAndStatusIn(Long driverId, List<RideStatus> statuses);

    List<Ride> findByStatus(RideStatus status);

    @Query("SELECT COUNT(r) FROM Ride r WHERE r.status = :status")
    long countByStatus(RideStatus status);

    @Query("SELECT SUM(r.actualFare) FROM Ride r WHERE r.status = 'COMPLETED' AND r.completedAt BETWEEN :start AND :end")
    Double sumRevenueByDateRange(@Param("start") LocalDateTime start, @Param("end") LocalDateTime end);

    @Query("SELECT COUNT(r) FROM Ride r WHERE r.completedAt BETWEEN :start AND :end AND r.status = 'COMPLETED'")
    long countCompletedRidesByDateRange(@Param("start") LocalDateTime start, @Param("end") LocalDateTime end);

    @Query("SELECT r FROM Ride r WHERE r.status IN ('REQUESTED', 'SEARCHING', 'DRIVER_ASSIGNED', 'DRIVER_ARRIVED', 'IN_PROGRESS')")
    List<Ride> findActiveRides();
}
