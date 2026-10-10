package com.rideet.service;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.Ride;
import com.rideet.domain.entity.User;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.RideStatus;
import com.rideet.domain.enums.UserRole;
import com.rideet.dto.response.DriverResponse;
import com.rideet.dto.response.RideResponse;
import com.rideet.dto.response.UserResponse;
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
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
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
    private final RideViewMapper rideViewMapper;
    private final UserViewMapper userViewMapper;
    private final MatchingService matchingService;
    private final DriverLocationIndex locationIndex;
    private final DriverPresenceCache presenceCache;

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
        log.info("Driver {} documents verified by admin", driverId);
        return driverService.toResponse(driverRepository.save(driver));
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
