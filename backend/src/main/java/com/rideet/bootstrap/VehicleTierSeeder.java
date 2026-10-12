package com.rideet.bootstrap;

import com.rideet.domain.entity.VehicleTier;
import com.rideet.domain.enums.VehicleType;
import com.rideet.repository.VehicleTierRepository;
import com.rideet.service.FareCalculationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Makes sure every {@link VehicleType} has a priced tier before the first quote is taken. Idempotent:
 * existing rows keep their values, so an operator's edits survive a restart.
 *
 * <p>Fares are quoted in ETB, matching what the apps display and what the seeded drivers charge.
 */
@Component
@Order(20)
@RequiredArgsConstructor
@Slf4j
public class VehicleTierSeeder implements ApplicationRunner {

    private final VehicleTierRepository tierRepository;
    private final FareCalculationService fareCalculationService;

    @Override
    public void run(ApplicationArguments args) {
        List<VehicleTier> missing = defaults().stream()
                .filter(t -> tierRepository.findByVehicleType(t.getVehicleType()).isEmpty())
                .toList();

        if (!missing.isEmpty()) {
            tierRepository.saveAll(missing);
            fareCalculationService.invalidateCache();
            log.info("Seeded {} vehicle tier(s): {}", missing.size(),
                    missing.stream().map(t -> t.getDisplayName() + " " + t.getBaseFare()).toList());
        }
    }

    private static List<VehicleTier> defaults() {
        return List.of(
                tier(VehicleType.ECONOMY, "Classic", 250.00, 1.80, 0.50, 250.00),
                tier(VehicleType.STANDARD, "Standard", 300.00, 2.00, 0.60, 300.00),
                tier(VehicleType.PREMIUM, "Premium", 400.00, 2.60, 0.80, 400.00),
                tier(VehicleType.XL, "XL", 400.00, 2.40, 0.70, 400.00));
    }

    private static VehicleTier tier(VehicleType type, String name, double base,
                                    double perKm, double perMin, double minimum) {
        return VehicleTier.builder()
                .vehicleType(type)
                .displayName(name)
                .baseFare(base)
                .perKmRate(perKm)
                .perMinuteRate(perMin)
                .bookingFee(0.0)
                .minimumFare(minimum)
                .surgeMultiplier(1.0)
                .active(true)
                .build();
    }
}
