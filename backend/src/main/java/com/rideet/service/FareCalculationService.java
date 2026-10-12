package com.rideet.service;

import com.rideet.domain.entity.VehicleTier;
import com.rideet.domain.enums.VehicleType;
import com.rideet.dto.response.FareEstimateResponse;
import com.rideet.repository.VehicleTierRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;

/**
 * Quotes fares from the {@code vehicle_tiers} table, so every tier can be priced independently
 * and changed by an operator without a redeploy. The {@code fare.*} properties are only used to
 * seed that table and as a last-resort fallback on a database that has not been seeded yet.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FareCalculationService {

    private final VehicleTierRepository tierRepository;

    @Value("${fare.base-fare:2.50}")
    private double baseFare;

    @Value("${fare.per-km-rate:1.20}")
    private double perKmRate;

    @Value("${fare.per-minute-rate:0.20}")
    private double perMinuteRate;

    @Value("${fare.minimum-fare:5.00}")
    private double minimumFare;

    @Value("${fare.surge-multiplier:1.0}")
    private double surgeMultiplier;

    private volatile Map<VehicleType, VehicleTier> cache;

    public List<VehicleTier> activeTiers() {
        List<VehicleTier> all = tiers();
        List<VehicleTier> active = all.stream().filter(VehicleTier::isActive).toList();
        return active.isEmpty() ? all : active;
    }

    public List<VehicleTier> tiers() {
        return List.copyOf(tierRepository.findAllByOrderByDisplayNameAsc());
    }

    public VehicleTier tierOf(VehicleType type) {
        VehicleTier tier = loaded().get(type);
        return tier != null ? tier : loaded().get(VehicleType.ECONOMY);
    }

    /** Called after an operator edits pricing so the next quote sees the new numbers. */
    public void invalidateCache() {
        cache = null;
    }

    private Map<VehicleType, VehicleTier> loaded() {
        Map<VehicleType, VehicleTier> local = cache;
        if (local == null) {
            local = new EnumMap<>(VehicleType.class);
            for (VehicleTier tier : tierRepository.findAll()) {
                local.put(tier.getVehicleType(), tier);
            }
            if (local.isEmpty()) {
                log.warn("vehicle_tiers is empty — quoting from the fare.* properties");
                for (VehicleType type : VehicleType.values()) {
                    local.put(type, fallbackTier(type));
                }
            }
            if (!local.containsKey(VehicleType.ECONOMY)) {
                local.put(VehicleType.ECONOMY, fallbackTier(VehicleType.ECONOMY));
            }
            cache = local;
        }
        return local;
    }

    private VehicleTier fallbackTier(VehicleType type) {
        return VehicleTier.builder()
                .vehicleType(type)
                .displayName(type.name())
                .baseFare(baseFare)
                .perKmRate(perKmRate)
                .perMinuteRate(perMinuteRate)
                .bookingFee(0.0)
                .minimumFare(minimumFare)
                .surgeMultiplier(surgeMultiplier)
                .active(true)
                .build();
    }

    /** Quote for a specific tier; the whole trip is priced, so the rider sees one number. */
    public FareEstimateResponse calculateFare(double distanceKm, int durationMinutes, VehicleType type) {
        VehicleTier tier = tierOf(type);
        return FareEstimateResponse.builder()
                .vehicleType(tier.getVehicleType())
                .displayName(tier.getDisplayName())
                .estimatedFare(tier.fareFor(distanceKm, durationMinutes))
                .distanceKm(round2(distanceKm))
                .durationMinutes(durationMinutes)
                .surgeMultiplier(tier.getSurgeMultiplier())
                .baseFare(tier.baseFareComponent())
                .distanceFare(tier.distanceFareFor(distanceKm))
                .timeFare(tier.timeFareFor(durationMinutes))
                .bookingFee(tier.getBookingFee())
                .build();
    }

    public FareEstimateResponse calculateFare(double distanceKm, int durationMinutes) {
        return calculateFare(distanceKm, durationMinutes, VehicleType.ECONOMY);
    }

    /**
     * Haversine formula to calculate distance between two coordinates.
     */
    public double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
        final int EARTH_RADIUS_KM = 6371;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS_KM * c;
    }

    /**
     * Estimate duration based on distance (avg 30 km/h in city).
     */
    public int estimateDurationMinutes(double distanceKm) {
        double avgSpeedKmh = 30.0;
        return (int) Math.ceil((distanceKm / avgSpeedKmh) * 60);
    }

    /** How long the nearest driver of this tier needs to reach the pickup, at city speeds. */
    public int pickupMinutes(double distanceKm) {
        double pickupSpeedKmh = 22.0;
        return Math.max(1, (int) Math.ceil((distanceKm / pickupSpeedKmh) * 60));
    }

    private static double round2(double v) {
        return Math.round(v * 100.0) / 100.0;
    }
}
