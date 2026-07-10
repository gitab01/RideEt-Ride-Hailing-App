package com.rideet.service;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.Ride;
import com.rideet.domain.entity.User;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.RideStatus;
import com.rideet.domain.enums.UserRole;
import com.rideet.exception.ResourceNotFoundException;
import com.rideet.repository.DriverRepository;
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
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class AdminService {

    private final UserRepository userRepository;
    private final DriverRepository driverRepository;
    private final RideRepository rideRepository;

    public Map<String, Object> getDashboardStats() {
        Map<String, Object> stats = new HashMap<>();

        stats.put("totalPassengers", userRepository.countByRole(UserRole.PASSENGER));
        stats.put("totalDrivers", driverRepository.count());
        stats.put("onlineDrivers", driverRepository.countByStatus(DriverStatus.ONLINE));
        stats.put("activeRides", rideRepository.findActiveRides().size());
        stats.put("totalRides", rideRepository.count());
        stats.put("completedRides", rideRepository.countByStatus(RideStatus.COMPLETED));

        LocalDateTime startOfDay = LocalDateTime.now().toLocalDate().atStartOfDay();
        LocalDateTime endOfDay = startOfDay.plusDays(1);
        Double todayRevenue = rideRepository.sumRevenueByDateRange(startOfDay, endOfDay);
        stats.put("todayRevenue", todayRevenue != null ? todayRevenue : 0.0);

        LocalDateTime startOfMonth = LocalDateTime.now().withDayOfMonth(1).toLocalDate().atStartOfDay();
        Double monthRevenue = rideRepository.sumRevenueByDateRange(startOfMonth, endOfDay);
        stats.put("monthRevenue", monthRevenue != null ? monthRevenue : 0.0);

        return stats;
    }

    public Page<User> getAllPassengers(Pageable pageable) {
        return userRepository.findAll(pageable);
    }

    public Page<Driver> getAllDrivers(Pageable pageable) {
        return driverRepository.findAll(pageable);
    }

    public List<Ride> getActiveRides() {
        return rideRepository.findActiveRides();
    }

    public Page<Ride> getAllRides(Pageable pageable) {
        return rideRepository.findAll(pageable);
    }

    @Transactional
    public Driver verifyDriverDocuments(Long driverId) {
        Driver driver = driverRepository.findById(driverId)
                .orElseThrow(() -> new ResourceNotFoundException("Driver not found"));
        driver.setDocumentsVerified(true);
        log.info("Driver {} documents verified by admin", driverId);
        return driverRepository.save(driver);
    }

    @Transactional
    public User toggleUserStatus(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        user.setEnabled(!user.isEnabled());
        user.setAccountNonLocked(!user.isAccountNonLocked());
        log.info("User {} status toggled: enabled={}", userId, user.isEnabled());
        return userRepository.save(user);
    }

    @Transactional
    public Driver toggleDriverSuspension(Long driverId) {
        Driver driver = driverRepository.findById(driverId)
                .orElseThrow(() -> new ResourceNotFoundException("Driver not found"));
        if (driver.getStatus() == DriverStatus.SUSPENDED) {
            driver.setStatus(DriverStatus.OFFLINE);
        } else {
            driver.setStatus(DriverStatus.SUSPENDED);
        }
        return driverRepository.save(driver);
    }
}
