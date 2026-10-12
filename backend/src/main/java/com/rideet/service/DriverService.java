package com.rideet.service;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.DriverLocation;
import com.rideet.domain.entity.Ride;
import com.rideet.domain.entity.User;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.RideStatus;
import com.rideet.dto.request.DriverRegisterRequest;
import com.rideet.dto.request.LocationUpdateRequest;
import com.rideet.dto.response.DriverEarningsResponse;
import com.rideet.dto.response.DriverResponse;
import com.rideet.exception.BadRequestException;
import com.rideet.exception.ResourceNotFoundException;
import com.rideet.matching.DriverLocationIndex;
import com.rideet.matching.DriverPresenceCache;
import com.rideet.matching.LocationWriteBuffer;
import com.rideet.repository.DriverRepository;
import com.rideet.repository.RideRepository;
import com.rideet.repository.UserRepository;
import com.rideet.websocket.RideWebSocketService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class DriverService {

    private final DriverRepository driverRepository;
    private final UserRepository userRepository;
    private final RideRepository rideRepository;
    private final RideWebSocketService rideWebSocketService;
    private final DriverLocationIndex locationIndex;
    private final LocationWriteBuffer locationBuffer;
    private final DriverPresenceCache presenceCache;

    /** Turn an already-registered user account into a driver. */
    @Transactional
    public DriverResponse register(Long userId, DriverRegisterRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        if (driverRepository.existsByUserId(userId)) {
            throw new BadRequestException("Driver profile already exists for this account");
        }

        Driver driver = Driver.builder()
                .user(user)
                .vehicleMake(request.getVehicleMake())
                .vehicleModel(request.getVehicleModel())
                .vehicleYear(request.getVehicleYear())
                .licensePlate(request.getLicensePlate().toUpperCase())
                .vehicleColor(request.getVehicleColor())
                .vehicleType(request.getVehicleType())
                .status(DriverStatus.OFFLINE)
                .build();

        Driver saved = driverRepository.save(driver);
        presenceCache.cache(saved);
        log.info("Driver profile {} created for user {}", saved.getId(), userId);
        return toResponse(saved);
    }

    @Transactional
    public DriverResponse submitDocuments(Long userId, String driverLicenseUrl,
                                          String vehicleRegistrationUrl, String insuranceUrl) {
        Driver driver = getDriverByUserId(userId);
        driver.setDriverLicenseUrl(driverLicenseUrl);
        driver.setVehicleRegistrationUrl(vehicleRegistrationUrl);
        driver.setInsuranceUrl(insuranceUrl);
        return toResponse(driverRepository.save(driver));
    }

    @Transactional
    public DriverResponse goOnline(Long userId) {
        Driver driver = getDriverByUserId(userId);
        if (!driver.isDocumentsVerified()) {
            throw new BadRequestException("Documents not verified yet");
        }
        if (driver.getStatus() == DriverStatus.SUSPENDED) {
            throw new BadRequestException("Your account is suspended; contact RideEt support");
        }
        if (driver.getStatus() == DriverStatus.ON_TRIP) {
            throw new BadRequestException("You are on a trip; finish it before going online");
        }
        driver.setStatus(DriverStatus.ONLINE);
        Driver saved = driverRepository.save(driver);
        presenceCache.statusChanged(userId, DriverStatus.ONLINE);

        if (saved.getCurrentLatitude() != null && saved.getCurrentLongitude() != null) {
            locationIndex.put(saved.getId(), userId, saved.getCurrentLatitude(),
                    saved.getCurrentLongitude(), saved.getVehicleType());
        }
        log.info("Driver {} online", saved.getId());
        return toResponse(saved);
    }

    @Transactional
    public DriverResponse goOffline(Long userId) {
        Driver driver = getDriverByUserId(userId);
        if (driver.getStatus() == DriverStatus.ON_TRIP) {
            throw new BadRequestException("Cannot go offline while on a trip");
        }
        driver.setStatus(DriverStatus.OFFLINE);
        Driver saved = driverRepository.save(driver);
        presenceCache.statusChanged(userId, DriverStatus.OFFLINE);
        locationIndex.remove(saved.getId());
        log.info("Driver {} offline", saved.getId());
        return toResponse(saved);
    }

    /**
     * Hot path. The live index is updated immediately and the durable trail is queued for
     * the batched flush; nothing here touches the database per ping.
     */
    public void updateLocation(Long userId, LocationUpdateRequest request) {
        if (request.getLatitude() == null || request.getLongitude() == null) return;

        DriverPresenceCache.Ref ref = presenceCache.get(userId);
        if (ref == null) {
            Driver loaded = getDriverByUserId(userId);
            ref = presenceCache.cache(loaded);
        }

        boolean placed = ref.getStatus() == DriverStatus.ONLINE || ref.getStatus() == DriverStatus.ON_TRIP;
        if (placed) {
            // An OFFLINE or SUSPENDED driver must never appear in a candidate list; ON_TRIP
            // drivers stay placed so the boarding check and the admin map see the truth.
            // Matching filters by status rather than by absence from this index.
            locationIndex.put(ref.getDriverId(), userId, request.getLatitude(),
                    request.getLongitude(), ref.getVehicleType());
            // The trail feeds the measured fare, so it has to cover the whole trip, not just
            // the cruise between jobs.
            locationBuffer.offer(DriverLocation.builder()
                    .driverId(ref.getDriverId())
                    .latitude(request.getLatitude())
                    .longitude(request.getLongitude())
                    .heading(request.getHeading())
                    .speedKmh(request.getSpeed())
                    .recordedAt(LocalDateTime.now())
                    .build());
            rideWebSocketService.broadcastToAdmin("DRIVER_LOCATION", Map.of(
                    "driverId", ref.getDriverId(),
                    "latitude", request.getLatitude(),
                    "longitude", request.getLongitude(),
                    "heading", request.getHeading() == null ? 0.0 : request.getHeading(),
                    "speed", request.getSpeed() == null ? 0.0 : request.getSpeed()));
        }

        rideWebSocketService.broadcastDriverLocation(userId, request.getLatitude(),
                request.getLongitude(), request.getHeading(), request.getSpeed(), null);
    }

    @Transactional(readOnly = true)
    public Driver getDriverByUserId(Long userId) {
        return driverRepository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found. Register as a driver first."));
    }

    @Transactional(readOnly = true)
    public DriverResponse getProfile(Long userId) {
        return toResponse(getDriverByUserId(userId));
    }

    /**
     * Everything the driver's earnings screen shows, totalled from this driver's COMPLETED rides.
     * Days with no work are still returned as zeroes so the chart cannot imply activity that did
     * not happen, and acceptance rate stays null until the driver has answered an offer.
     */
    @Transactional(readOnly = true)
    public DriverEarningsResponse earnings(Long userId, int windowDays) {
        Driver driver = getDriverByUserId(userId);
        int days = Math.min(Math.max(windowDays, 1), 60);
        LocalDate today = LocalDate.now();

        Map<LocalDate, long[]> perDay = new LinkedHashMap<>();
        for (int i = days - 1; i >= 0; i--) {
            perDay.put(today.minusDays(i), new long[]{0, 0});   // rides, cents
        }

        List<Ride> completed = rideRepository
                .findByDriverIdAndStatusAndCompletedAtBetweenOrderByCompletedAtAsc(
                        driver.getId(), RideStatus.COMPLETED,
                        today.minusDays(days - 1L).atStartOfDay(),
                        today.plusDays(1).atStartOfDay());

        for (Ride ride : completed) {
            long[] bucket = perDay.get(ride.getCompletedAt().toLocalDate());
            if (bucket == null) continue;
            bucket[0]++;
            bucket[1] += Math.round((ride.getActualFare() == null ? 0.0 : ride.getActualFare()) * 100.0);
        }

        List<DriverEarningsResponse.DayEarnings> series = new ArrayList<>();
        long windowRides = 0;
        long windowCents = 0;
        for (Map.Entry<LocalDate, long[]> entry : perDay.entrySet()) {
            series.add(DriverEarningsResponse.DayEarnings.builder()
                    .date(entry.getKey().toString())
                    .rides((int) entry.getValue()[0])
                    .amount(entry.getValue()[1] / 100.0)
                    .build());
            windowRides += entry.getValue()[0];
            windowCents += entry.getValue()[1];
        }

        long[] todayBucket = perDay.get(today);
        int answered = driver.getOffersAccepted() + driver.getOffersDeclined();

        return DriverEarningsResponse.builder()
                .todayEarnings(todayBucket[1] / 100.0)
                .windowEarnings(windowCents / 100.0)
                .lifetimeEarnings(driver.getTotalEarnings())
                .walletBalance(driver.getUser().getWalletBalance())
                .todayRides((int) todayBucket[0])
                .windowRides((int) windowRides)
                .totalRides(driver.getTotalRides())
                .windowDays(days)
                .rating(driver.getRating())
                .totalRatings(driver.getTotalRatings())
                .acceptanceRatePercent(answered == 0
                        ? null
                        : (int) Math.round(100.0 * driver.getOffersAccepted() / answered))
                .days(series)
                .build();
    }

    public DriverResponse toResponse(Driver driver) {
        User user = driver.getUser();
        return DriverResponse.builder()
                .id(driver.getId())
                .userId(user == null ? null : user.getId())
                .fullName(user == null ? null : user.getFullName())
                .phone(user == null ? null : user.getPhone())
                .email(user == null ? null : user.getEmail())
                .vehicleMake(driver.getVehicleMake())
                .vehicleModel(driver.getVehicleModel())
                .vehicleYear(driver.getVehicleYear())
                .licensePlate(driver.getLicensePlate())
                .vehicleColor(driver.getVehicleColor())
                .vehicleType(driver.getVehicleType())
                .driverLicenseUrl(driver.getDriverLicenseUrl())
                .vehicleRegistrationUrl(driver.getVehicleRegistrationUrl())
                .insuranceUrl(driver.getInsuranceUrl())
                .status(driver.getStatus())
                .documentsVerified(driver.isDocumentsVerified())
                .verificationNote(driver.getVerificationNote())
                .offersAccepted(driver.getOffersAccepted())
                .offersDeclined(driver.getOffersDeclined())
                .currentLatitude(driver.getCurrentLatitude())
                .currentLongitude(driver.getCurrentLongitude())
                .lastLocationUpdate(driver.getLastLocationUpdate())
                .rating(driver.getRating())
                .totalRatings(driver.getTotalRatings())
                .totalRides(driver.getTotalRides())
                .totalEarnings(driver.getTotalEarnings())
                .enabled(user == null ? null : user.isEnabled())
                .createdAt(driver.getCreatedAt())
                .build();
    }
}
