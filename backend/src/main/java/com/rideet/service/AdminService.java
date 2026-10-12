package com.rideet.service;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.Ride;
import com.rideet.domain.entity.User;
import com.rideet.domain.entity.VehicleTier;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.RideStatus;
import com.rideet.domain.enums.UserRole;
import com.rideet.domain.enums.VehicleType;
import com.rideet.dto.request.DriverRejectionRequest;
import com.rideet.dto.request.VehicleTierUpdateRequest;
import com.rideet.dto.response.AdminDailyStatsResponse;
import com.rideet.dto.response.DriverResponse;
import com.rideet.dto.response.RideResponse;
import com.rideet.dto.response.UserResponse;
import com.rideet.dto.response.VehicleTierResponse;
import com.rideet.exception.ResourceNotFoundException;
import com.rideet.mapper.RideViewMapper;
import com.rideet.mapper.UserViewMapper;
import com.rideet.matching.DriverLocationIndex;
import com.rideet.matching.DriverPresenceCache;
import com.rideet.matching.MatchingService;
import com.rideet.repository.DriverRepository;
import com.rideet.repository.RideEventRepository;
import com.rideet.repository.RideRepository;
import com.rideet.repository.UserRepository;
import com.rideet.repository.VehicleTierRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Console-facing reads and the two operational levers an admin has: verify a driver's
 * documents, suspend an account. Every read returns a DTO because the entities carry lazy
 * associations that cannot be serialised once {@code open-in-view} is off.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AdminService {

    private static final List<RideStatus> ACTIVE_STATUSES = List.of(
            RideStatus.REQUESTED, RideStatus.SEARCHING,
            RideStatus.DRIVER_ASSIGNED, RideStatus.DRIVER_ARRIVED, RideStatus.IN_PROGRESS);

    private final UserRepository userRepository;
    private final DriverRepository driverRepository;
    private final RideRepository rideRepository;
    private final RideEventRepository rideEventRepository;
    private final DriverService driverService;
    private final RideService rideService;
    private final RideViewMapper rideViewMapper;
    private final UserViewMapper userViewMapper;
    private final MatchingService matchingService;
    private final DriverLocationIndex locationIndex;
    private final DriverPresenceCache presenceCache;
    private final VehicleTierRepository tierRepository;
    private final FareCalculationService fareCalculationService;

    @Value("${matching.max-radius-km:12.0}")
    private double searchRadiusKm;

    @Transactional(readOnly = true)
    public Map<String, Object> getDashboardStats() {
        Map<String, Object> stats = new HashMap<>();

        stats.put("totalPassengers", userRepository.countByRole(UserRole.PASSENGER));
        stats.put("totalDrivers", driverRepository.count());
        stats.put("onlineDrivers", driverRepository.countByStatus(DriverStatus.ONLINE));
        stats.put("activeRides", rideRepository.countByStatusIn(ACTIVE_STATUSES));
        stats.put("totalRides", rideRepository.count());
        stats.put("completedRides", rideRepository.countByStatus(RideStatus.COMPLETED));

        LocalDateTime startOfDay = LocalDateTime.now().toLocalDate().atStartOfDay();
        LocalDateTime endOfDay = startOfDay.plusDays(1);
        Double todayRevenue = rideRepository.sumRevenueByDateRange(
                RideStatus.COMPLETED, startOfDay, endOfDay);
        stats.put("todayRevenue", todayRevenue != null ? todayRevenue : 0.0);

        LocalDateTime startOfMonth = LocalDateTime.now().withDayOfMonth(1).toLocalDate().atStartOfDay();
        Double monthRevenue = rideRepository.sumRevenueByDateRange(
                RideStatus.COMPLETED, startOfMonth, endOfDay);
        stats.put("monthRevenue", monthRevenue != null ? monthRevenue : 0.0);

        stats.put("searchesInProgress", matchingService.activeRounds());
        stats.put("trackedDrivers", locationIndex.size());

        return stats;
    }

    @Transactional(readOnly = true)
    public Page<UserResponse> getAllUsers(Pageable pageable) {
        return userRepository.findAll(pageable).map(userViewMapper::toResponse);
    }

    @Transactional(readOnly = true)
    public Page<DriverResponse> getAllDrivers(Pageable pageable) {
        return driverRepository.findAllWithUser(pageable).map(driverService::toResponse);
    }

    @Transactional(readOnly = true)
    public List<RideResponse> getActiveRides() {
        return rideRepository.findActiveRides(ACTIVE_STATUSES).stream()
                .map(this::toAdminRideView)
                .toList();
    }

    @Transactional(readOnly = true)
    public Page<RideResponse> getAllRides(Pageable pageable) {
        return rideRepository.findAll(pageable).map(this::toAdminRideView);
    }

    /** Who moved this ride, to what, when — the record a dispute is settled from. */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> getRideEvents(Long rideId) {
        return rideEventRepository.findByRideIdOrderByCreatedAtAsc(rideId).stream()
                .map(event -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("from", event.getFromStatus());
                    row.put("to", event.getToStatus());
                    row.put("actor", event.getActor());
                    row.put("note", event.getNote());
                    row.put("at", event.getCreatedAt());
                    return row;
                })
                .toList();
    }

    @Transactional
    public DriverResponse verifyDriverDocuments(Long driverId) {
        Driver driver = driverRepository.findByIdWithUser(driverId)
                .orElseThrow(() -> new ResourceNotFoundException("Driver not found"));
        driver.setDocumentsVerified(true);
        driver.setVerificationNote(null);
        log.info("Driver {} documents verified by admin", driverId);
        return driverService.toResponse(driverRepository.save(driver));
    }

    /**
     * Rejecting a driver's paperwork has to end their shift, not just flag the row: an
     * unapproved driver must stop receiving offers at once rather than at their next ping.
     */
    @Transactional
    public DriverResponse rejectDriverDocuments(Long driverId, DriverRejectionRequest request) {
        Driver driver = driverRepository.findByIdWithUser(driverId)
                .orElseThrow(() -> new ResourceNotFoundException("Driver not found"));
        driver.setDocumentsVerified(false);
        driver.setVerificationNote(request.getReason());
        if (driver.getStatus() == DriverStatus.ONLINE) {
            driver.setStatus(DriverStatus.OFFLINE);
            presenceCache.statusChanged(driver.getUser().getId(), DriverStatus.OFFLINE);
            locationIndex.remove(driverId);
        }
        log.info("Driver {} documents rejected: {}", driverId, request.getReason());
        return driverService.toResponse(driverRepository.save(driver));
    }

    /**
     * Live map feed. Read straight from the matching index, so what an admin sees is the same
     * placement the engine matches against rather than a row that lags behind a batched write.
     * Deliberately without names or plates: the console already has {@code /admin/drivers}
     * to join these six fields against.
     */
    public List<Map<String, Object>> getDriverLocations() {
        List<Map<String, Object>> rows = new ArrayList<>();
        for (DriverLocationIndex.Placement p : locationIndex.snapshot()) {
            DriverPresenceCache.Ref ref = presenceCache.get(p.userId());
            LocalDateTime seenAt = LocalDateTime.ofInstant(
                    Instant.ofEpochMilli(p.updatedAtMillis()), ZoneId.systemDefault());
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("driverId", p.driverId());
            row.put("userId", p.userId());
            row.put("latitude", p.latitude());
            row.put("longitude", p.longitude());
            row.put("vehicleType", p.vehicleType());
            row.put("status", ref == null ? null : ref.getStatus());
            row.put("seenAt", seenAt);
            row.put("secondsAgo", java.time.Duration.between(seenAt, LocalDateTime.now()).getSeconds());
            rows.add(row);
        }
        return rows;
    }

    /**
     * Who an admin could put on a waiting ride, nearest first, across every tier — the whole
     * point of manual dispatch is reaching a car the automatic round could not. Each candidate
     * carries the fare that tier would charge for this exact trip, so choosing a bigger car is a
     * priced decision rather than a guess.
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> getDispatchCandidates(Long rideId) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));
        if (ride.getStatus() != RideStatus.SEARCHING) {
            return List.of();
        }

        List<DriverLocationIndex.Candidate> nearby = locationIndex.nearest(
                ride.getPickupLatitude(), ride.getPickupLongitude(), searchRadiusKm, null, null, 10);
        if (nearby.isEmpty()) return List.of();

        List<Long> ids = nearby.stream().map(DriverLocationIndex.Candidate::driverId).toList();
        Map<Long, Driver> byId = new HashMap<>();
        for (Driver d : driverRepository.findAllWithUserByIds(ids)) {
            byId.put(d.getId(), d);
        }

        double distanceKm = ride.getDistanceKm() != null ? ride.getDistanceKm() : 0.0;
        int durationMinutes = ride.getDurationMinutes() != null ? ride.getDurationMinutes() : 0;

        List<Map<String, Object>> rows = new ArrayList<>();
        for (DriverLocationIndex.Candidate candidate : nearby) {
            Driver driver = byId.get(candidate.driverId());
            if (driver == null || driver.getStatus() != DriverStatus.ONLINE
                    || !driver.isDocumentsVerified()) {
                continue;
            }
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("driverId", driver.getId());
            row.put("userId", driver.getUser() == null ? null : driver.getUser().getId());
            row.put("fullName", driver.getUser() == null ? null : driver.getUser().getFullName());
            row.put("vehicleType", driver.getVehicleType());
            row.put("licensePlate", driver.getLicensePlate());
            row.put("rating", driver.getRating());
            row.put("distanceToPickupKm", candidate.distanceKm());
            row.put("pickupEtaMinutes", fareCalculationService.pickupMinutes(candidate.distanceKm()));
            row.put("fareForThisTrip",
                    fareCalculationService.calculateFare(distanceKm, durationMinutes, driver.getVehicleType())
                            .getEstimatedFare());
            row.put("differentTier", driver.getVehicleType() != ride.getVehicleType());
            rows.add(row);
        }
        return rows;
    }

    /** Manual dispatch. The engine decides whether the driver can actually take the ride. */
    @Transactional
    public RideResponse assignDriver(Long rideId, Long driverId) {
        Ride ride = matchingService.adminAssign(driverId, rideId);
        return toAdminRideView(ride);
    }

    @Transactional
    public RideResponse cancelRide(Long rideId, String reason) {
        return rideService.cancelByAdmin(rideId, reason);
    }

    /**
     * Requests and takings per day for the dashboard charts, zero-filled across the whole window
     * so a quiet Tuesday still shows as a Tuesday.
     */
    @Transactional(readOnly = true)
    public AdminDailyStatsResponse getDailyStats(int days) {
        int window = Math.min(Math.max(days, 1), 90);
        LocalDate today = LocalDate.now();
        LocalDate first = today.minusDays(window - 1L);
        LocalDateTime from = first.atStartOfDay();

        Map<LocalDate, long[]> ridesByDay = new LinkedHashMap<>();
        for (int i = 0; i < window; i++) {
            ridesByDay.put(first.plusDays(i), new long[]{0L});
        }
        for (Object[] row : rideRepository.countRequestedByDay(from)) {
            LocalDate day = asLocalDate(row[0]);
            long[] cell = ridesByDay.get(day);
            if (cell != null) cell[0] = ((Number) row[1]).longValue();
        }

        Map<LocalDate, Double> revenueByDay = new HashMap<>();
        for (Object[] row : rideRepository.revenueByDay(RideStatus.COMPLETED, from)) {
            revenueByDay.put(asLocalDate(row[0]), row[1] == null ? 0.0 : ((Number) row[1]).doubleValue());
        }

        List<AdminDailyStatsResponse.Day> series = new ArrayList<>();
        long totalRides = 0;
        double totalRevenue = 0.0;
        for (Map.Entry<LocalDate, long[]> entry : ridesByDay.entrySet()) {
            double revenue = round2(revenueByDay.getOrDefault(entry.getKey(), 0.0));
            totalRides += entry.getValue()[0];
            totalRevenue += revenue;
            series.add(AdminDailyStatsResponse.Day.builder()
                    .date(entry.getKey())
                    .rides(entry.getValue()[0])
                    .revenue(revenue)
                    .build());
        }

        return AdminDailyStatsResponse.builder()
                .windowDays(window)
                .totalRides(totalRides)
                .totalRevenue(round2(totalRevenue))
                .days(series)
                .build();
    }

    /** Hibernate hands back a date as LocalDate on the new drivers and java.sql.Date on some paths. */
    private LocalDate asLocalDate(Object value) {
        if (value instanceof LocalDate date) return date;
        if (value instanceof java.sql.Date date) return date.toLocalDate();
        if (value instanceof LocalDateTime dateTime) return dateTime.toLocalDate();
        throw new IllegalStateException("Unexpected day column type: " + value);
    }

    private static double round2(double value) {
        return Math.round(value * 100.0) / 100.0;
    }

    @Transactional(readOnly = true)
    public List<VehicleTierResponse> getPricing() {
        return fareCalculationService.tiers().stream().map(this::toTierResponse).toList();
    }

    /**
     * Edit one tier's pricing. The vehicle type is the key and stays untouched; the fare cache is
     * dropped so the next quote sees the new numbers instead of the ones loaded at startup.
     */
    @Transactional
    public VehicleTierResponse updatePricing(VehicleType vehicleType, VehicleTierUpdateRequest request) {
        VehicleTier tier = tierRepository.findByVehicleType(vehicleType)
                .orElseThrow(() -> new ResourceNotFoundException("No such service tier"));
        tier.setDisplayName(request.getDisplayName());
        tier.setBaseFare(request.getBaseFare());
        tier.setPerKmRate(request.getPerKmRate());
        tier.setPerMinuteRate(request.getPerMinuteRate());
        tier.setBookingFee(request.getBookingFee());
        tier.setMinimumFare(request.getMinimumFare());
        tier.setSurgeMultiplier(request.getSurgeMultiplier());
        tier.setActive(request.getActive());
        tierRepository.save(tier);
        fareCalculationService.invalidateCache();
        log.info("Pricing for tier {} updated by admin", vehicleType);
        return toTierResponse(tier);
    }

    private VehicleTierResponse toTierResponse(VehicleTier tier) {
        return VehicleTierResponse.builder()
                .id(tier.getId())
                .vehicleType(tier.getVehicleType())
                .displayName(tier.getDisplayName())
                .baseFare(tier.getBaseFare())
                .perKmRate(tier.getPerKmRate())
                .perMinuteRate(tier.getPerMinuteRate())
                .bookingFee(tier.getBookingFee())
                .minimumFare(tier.getMinimumFare())
                .surgeMultiplier(tier.getSurgeMultiplier())
                .active(tier.isActive())
                .updatedAt(tier.getUpdatedAt())
                .sampleFare10km(tier.fareFor(10.0, 20))
                .build();
    }

    @Transactional
    public UserResponse toggleUserStatus(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        user.setEnabled(!user.isEnabled());
        user.setAccountNonLocked(!user.isAccountNonLocked());
        log.info("User {} status toggled: enabled={}", userId, user.isEnabled());
        return userViewMapper.toResponse(userRepository.save(user));
    }

    @Transactional
    public DriverResponse toggleDriverSuspension(Long driverId) {
        Driver driver = driverRepository.findByIdWithUser(driverId)
                .orElseThrow(() -> new ResourceNotFoundException("Driver not found"));
        Long userId = driver.getUser().getId();
        if (driver.getStatus() == DriverStatus.SUSPENDED) {
            driver.setStatus(DriverStatus.OFFLINE);
            presenceCache.statusChanged(userId, DriverStatus.OFFLINE);
            // A driver who has never sent a ping has no placement to restore.
            if (driver.getCurrentLatitude() != null && driver.getCurrentLongitude() != null) {
                locationIndex.put(driver.getId(), userId,
                        driver.getCurrentLatitude(), driver.getCurrentLongitude(), driver.getVehicleType());
            }
        } else {
            // A suspended driver must stop receiving offers immediately, not at their next ping.
            driver.setStatus(DriverStatus.SUSPENDED);
            presenceCache.statusChanged(userId, DriverStatus.SUSPENDED);
            locationIndex.remove(driverId);
        }
        return driverService.toResponse(driverRepository.save(driver));
    }

    /** Admins see both sides of a ride, including the fare actually charged. */
    private RideResponse toAdminRideView(Ride ride) {
        return rideViewMapper.toResponse(ride, null);
    }
}
