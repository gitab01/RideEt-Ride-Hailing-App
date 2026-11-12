package com.rideet.service;

import com.rideet.domain.entity.VehicleTier;
import com.rideet.domain.enums.VehicleType;
import com.rideet.dto.response.FareEstimateResponse;
import com.rideet.repository.VehicleTierRepository;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Fares are read from the {@code vehicle_tiers} table and cached, so both halves matter: what a
 * row computes, and how long an operator's edit takes to show up in a quote.
 */
class FareCalculationServiceTest {

    private static VehicleTier tier(VehicleType type, double base, double perKm,
                                   double perMinute, double bookingFee, double minimum,
                                   double surge) {
        return VehicleTier.builder()
                .vehicleType(type)
                .displayName(type.name())
                .baseFare(base)
                .perKmRate(perKm)
                .perMinuteRate(perMinute)
                .bookingFee(bookingFee)
                .minimumFare(minimum)
                .surgeMultiplier(surge)
                .active(true)
                .build();
    }

    private static FareCalculationService quoting(VehicleTier... tiers) {
        VehicleTierRepository repository = mock(VehicleTierRepository.class);
        when(repository.findAll()).thenReturn(List.of(tiers));
        return new FareCalculationService(repository);
    }

    @Test
    void eachTierPricesItsOwnTrip() {
        FareCalculationService service = quoting(
                tier(VehicleType.ECONOMY, 250.0, 1.8, 0.5, 0.0, 250.0, 1.0),
                tier(VehicleType.PREMIUM, 400.0, 2.6, 0.8, 0.0, 400.0, 1.0));

        // The 7.93 km / 16 min Meskel Square to Bole Airport trip the dev server quotes.
        assertEquals(272.27, service.calculateFare(7.93, 16, VehicleType.ECONOMY).getEstimatedFare());
        assertEquals(433.42, service.calculateFare(7.93, 16, VehicleType.PREMIUM).getEstimatedFare());
    }

    @Test
    void surgeMultipliesTheTripButNeverTheBookingFee() {
        FareCalculationService calm = quoting(
                tier(VehicleType.STANDARD, 300.0, 2.0, 0.6, 20.0, 300.0, 1.0));
        FareCalculationService busy = quoting(
                tier(VehicleType.STANDARD, 300.0, 2.0, 0.6, 20.0, 300.0, 1.5));

        // (300 + 2 km * 2.0 + 0 min * 0.6) = 304, plus the 20 fee that demand does not touch.
        assertEquals(324.0, calm.calculateFare(2.0, 0, VehicleType.STANDARD).getEstimatedFare());
        FareEstimateResponse surged = busy.calculateFare(2.0, 0, VehicleType.STANDARD);
        assertEquals(476.0, surged.getEstimatedFare());

        // Only the booking fee sits outside the multiplier; base and distance both move.
        assertEquals(450.0, surged.getBaseFare());
        assertEquals(6.0, surged.getDistanceFare());
        assertEquals(20.0, surged.getBookingFee());
        assertEquals(surged.getEstimatedFare(),
                surged.getBaseFare() + surged.getDistanceFare()
                        + surged.getTimeFare() + surged.getBookingFee(), 0.001);
    }

    @Test
    void theMinimumFareFloorsAStubOfATrip() {
        FareCalculationService service = quoting(
                tier(VehicleType.ECONOMY, 40.0, 1.8, 0.5, 0.0, 250.0, 1.0));

        assertEquals(250.0, service.calculateFare(0.4, 2, VehicleType.ECONOMY).getEstimatedFare());
    }

    @Test
    void anEditedRateOnlyReachesQuotesAfterTheCacheIsDropped() {
        VehicleTierRepository repository = mock(VehicleTierRepository.class);
        when(repository.findAll()).thenReturn(
                List.of(tier(VehicleType.ECONOMY, 250.0, 1.8, 0.5, 0.0, 250.0, 1.0)));
        FareCalculationService service = new FareCalculationService(repository);

        assertEquals(272.27, service.calculateFare(7.93, 16, VehicleType.ECONOMY).getEstimatedFare());

        when(repository.findAll()).thenReturn(
                List.of(tier(VehicleType.ECONOMY, 300.0, 1.8, 0.5, 0.0, 300.0, 1.0)));

        assertEquals(272.27, service.calculateFare(7.93, 16, VehicleType.ECONOMY).getEstimatedFare(),
                "the cached tier is still what a quote sees");

        service.invalidateCache();
        assertEquals(322.27, service.calculateFare(7.93, 16, VehicleType.ECONOMY).getEstimatedFare());
    }

    @Test
    void distanceIsMeasuredOnAGreatCircle() {
        FareCalculationService service = quoting(
                tier(VehicleType.ECONOMY, 250.0, 1.8, 0.5, 0.0, 250.0, 1.0));

        assertEquals(0.0, service.calculateDistanceKm(9.035, 38.75, 9.035, 38.75), 0.0001);
        assertEquals(7.9, service.calculateDistanceKm(9.035, 38.75, 8.975, 38.789), 0.3);
    }

    @Test
    void anEtaIsNeverZeroMinutes() {
        FareCalculationService service = quoting(
                tier(VehicleType.ECONOMY, 250.0, 1.8, 0.5, 0.0, 250.0, 1.0));

        assertEquals(1, service.pickupMinutes(0.05));
        assertEquals(1, service.pickupMinutes(0.0));
        org.junit.jupiter.api.Assertions.assertTrue(
                service.estimateDurationMinutes(10.0) >= service.estimateDurationMinutes(2.0));
    }
}
