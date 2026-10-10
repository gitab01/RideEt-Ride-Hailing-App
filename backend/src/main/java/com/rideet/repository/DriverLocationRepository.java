package com.rideet.repository;

import com.rideet.domain.entity.DriverLocation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface DriverLocationRepository extends JpaRepository<DriverLocation, Long> {

    List<DriverLocation> findByDriverIdAndRecordedAtBetweenOrderByRecordedAtAsc(
            Long driverId, LocalDateTime from, LocalDateTime to);

    @Modifying
    @Query("DELETE FROM DriverLocation l WHERE l.recordedAt < :cutoff")
    int deleteOlderThan(@Param("cutoff") LocalDateTime cutoff);
}
