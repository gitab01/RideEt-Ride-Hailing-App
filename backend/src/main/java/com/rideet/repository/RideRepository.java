package com.rideet.repository;

import com.rideet.domain.entity.Ride;
import com.rideet.domain.enums.RideStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
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

    /** Completed rides in a window, oldest first — the earnings screen groups these by day. */
    List<Ride> findByDriverIdAndStatusAndCompletedAtBetweenOrderByCompletedAtAsc(
            Long driverId, RideStatus status, LocalDateTime from, LocalDateTime to);

    Optional<Ride> findFirstByPassengerIdAndStatusIn(Long passengerId, List<RideStatus> statuses);

    Optional<Ride> findFirstByDriverIdAndStatusIn(Long driverId, List<RideStatus> statuses);

    List<Ride> findByStatus(RideStatus status);

    List<Ride> findByStatusIn(List<RideStatus> statuses);

    long countByStatusIn(List<RideStatus> statuses);

    @Query("SELECT COUNT(r) FROM Ride r WHERE r.status = :status")
    long countByStatus(@Param("status") RideStatus status);

    @Query("SELECT SUM(r.actualFare) FROM Ride r WHERE r.status = :status "
            + "AND r.completedAt BETWEEN :start AND :end")
    Double sumRevenueByDateRange(@Param("status") RideStatus status,
                                 @Param("start") LocalDateTime start,
                                 @Param("end") LocalDateTime end);

    @Query("SELECT COUNT(r) FROM Ride r WHERE r.status = :status AND r.completedAt BETWEEN :start AND :end")
    long countCompletedRidesByDateRange(@Param("status") RideStatus status,
                                        @Param("start") LocalDateTime start,
                                        @Param("end") LocalDateTime end);

    @Query("SELECT r FROM Ride r WHERE r.status IN :statuses ORDER BY r.requestedAt DESC")
    List<Ride> findActiveRides(@Param("statuses") List<RideStatus> statuses);

    /**
     * Compare-and-set on ride status: exactly one concurrent caller gets 1 row updated.
     */
    @Modifying(clearAutomatically = true)
    @Query("UPDATE Ride r SET r.status = :to WHERE r.id = :id AND r.status = :from")
    int compareAndSetStatus(@Param("id") Long id,
                            @Param("from") RideStatus from,
                            @Param("to") RideStatus to);

    @Query("SELECT r FROM Ride r WHERE r.status = :status AND r.requestedAt < :before")
    List<Ride> findByStatusRequestedBefore(@Param("status") RideStatus status,
                                           @Param("before") LocalDateTime before);

    Optional<Ride> findByIdAndPassengerId(Long id, Long passengerId);

    /**
     * Daily volume for the dashboard trend chart, counted from when the ride was requested.
     * Days with no rides are absent — the caller zero-fills so the chart keeps its x-axis.
     */
    @Query("SELECT CAST(r.requestedAt AS DATE), COUNT(r) FROM Ride r WHERE r.requestedAt >= :from "
            + "GROUP BY CAST(r.requestedAt AS DATE) ORDER BY 1")
    List<Object[]> countRequestedByDay(@Param("from") LocalDateTime from);

    /** Daily takings, from the fare actually charged on completed rides. */
    @Query("SELECT CAST(r.completedAt AS DATE), SUM(r.actualFare), COUNT(r) FROM Ride r "
            + "WHERE r.status = :status AND r.completedAt >= :from "
            + "GROUP BY CAST(r.completedAt AS DATE) ORDER BY 1")
    List<Object[]> revenueByDay(@Param("status") RideStatus status,
                                @Param("from") LocalDateTime from);

    @Query("SELECT r FROM Ride r WHERE r.status = :status ORDER BY r.requestedAt DESC")
    Page<Ride> findByStatusPaged(@Param("status") RideStatus status, Pageable pageable);
}
