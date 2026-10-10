package com.rideet.repository;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.VehicleType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface DriverRepository extends JpaRepository<Driver, Long> {

    Optional<Driver> findByUserId(Long userId);

    boolean existsByUserId(Long userId);

    List<Driver> findByStatus(DriverStatus status);

    long countByStatus(DriverStatus status);

    /**
     * Drivers eligible for matching. Live nearest-first search runs against the
     * in-memory grid index; this query only rebuilds that index at startup.
     */
    @Query("SELECT d FROM Driver d WHERE d.status = :status AND d.documentsVerified = true "
            + "AND d.currentLatitude IS NOT NULL AND d.currentLongitude IS NOT NULL")
    List<Driver> findMatchable(@Param("status") DriverStatus status);

    @Query("SELECT d FROM Driver d WHERE d.status = :status AND d.documentsVerified = true "
            + "AND d.currentLatitude IS NOT NULL AND d.currentLongitude IS NOT NULL "
            + "AND d.vehicleType = :vehicleType")
    List<Driver> findMatchable(@Param("status") DriverStatus status,
                               @Param("vehicleType") VehicleType vehicleType);

    @Query("SELECT COUNT(d) FROM Driver d WHERE d.status = :status")
    long countAllByStatus(@Param("status") DriverStatus status);

    /**
     * Admin listing: the user association is joined eagerly so the page is one query
     * and the DTO mapper never touches an unfetched proxy.
     */
    @Query("SELECT d FROM Driver d JOIN FETCH d.user ORDER BY d.createdAt DESC")
    Page<Driver> findAllWithUser(Pageable pageable);

    @Query("SELECT d FROM Driver d JOIN FETCH d.user WHERE d.id = :id")
    Optional<Driver> findByIdWithUser(@Param("id") Long id);

    /**
     * Last-known position, refreshed in bulk by the scheduled location flush rather than
     * once per ping.
     */
    @Modifying
    @Query("UPDATE Driver d SET d.currentLatitude = :lat, d.currentLongitude = :lng, "
            + "d.lastLocationUpdate = :at WHERE d.id = :id")
    void refreshPosition(@Param("id") Long id,
                         @Param("lat") Double lat,
                         @Param("lng") Double lng,
                         @Param("at") java.time.LocalDateTime at);
}
