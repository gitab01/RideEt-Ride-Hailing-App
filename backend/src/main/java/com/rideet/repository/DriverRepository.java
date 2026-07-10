package com.rideet.repository;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.VehicleType;
import org.springframework.data.jpa.repository.JpaRepository;
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

    /**
     * Find online drivers within a radius using Haversine formula (approx).
     * Returns drivers sorted by distance ascending.
     */
    @Query(value = """
            SELECT *, 
                (6371 * ACOS(
                    COS(RADIANS(:lat)) * COS(RADIANS(current_latitude)) *
                    COS(RADIANS(current_longitude) - RADIANS(:lng)) +
                    SIN(RADIANS(:lat)) * SIN(RADIANS(current_latitude))
                )) AS distance
            FROM drivers
            WHERE status = 'ONLINE'
              AND documents_verified = 1
              AND current_latitude IS NOT NULL
              AND current_longitude IS NOT NULL
              AND vehicle_type = :vehicleType
            HAVING distance <= :radiusKm
            ORDER BY distance ASC
            """, nativeQuery = true)
    List<Driver> findNearbyOnlineDrivers(
            @Param("lat") double latitude,
            @Param("lng") double longitude,
            @Param("radiusKm") double radiusKm,
            @Param("vehicleType") String vehicleType
    );

    @Query("SELECT COUNT(d) FROM Driver d WHERE d.status = :status")
    long countByStatus(DriverStatus status);
}
