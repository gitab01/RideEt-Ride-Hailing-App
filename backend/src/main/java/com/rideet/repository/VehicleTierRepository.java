package com.rideet.repository;

import com.rideet.domain.entity.VehicleTier;
import com.rideet.domain.enums.VehicleType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface VehicleTierRepository extends JpaRepository<VehicleTier, Long> {

    Optional<VehicleTier> findByVehicleType(VehicleType vehicleType);

    List<VehicleTier> findAllByOrderByDisplayNameAsc();

    List<VehicleTier> findByActiveTrueOrderByDisplayNameAsc();
}
