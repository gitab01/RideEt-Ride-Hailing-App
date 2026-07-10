package com.rideet.service;

import com.rideet.dto.response.FareEstimateResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class FareCalculationService {

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

    /**
     * Calculate fare based on distance and estimated duration.
     */
    public FareEstimateResponse calculateFare(double distanceKm, int durationMinutes) {
        double distanceFare = distanceKm * perKmRate;
        double timeFare = durationMinutes * perMinuteRate;
        double totalFare = (baseFare + distanceFare + timeFare) * surgeMultiplier;
        double finalFare = Math.max(totalFare, minimumFare);

        // Round to 2 decimal places
        finalFare = Math.round(finalFare * 100.0) / 100.0;

        return FareEstimateResponse.builder()
                .estimatedFare(finalFare)
                .distanceKm(distanceKm)
                .durationMinutes(durationMinutes)
                .surgeMultiplier(surgeMultiplier)
                .baseFare(baseFare)
                .distanceFare(Math.round(distanceFare * 100.0) / 100.0)
                .timeFare(Math.round(timeFare * 100.0) / 100.0)
                .build();
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
}
