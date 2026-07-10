package com.rideet.service;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.User;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.dto.request.LocationUpdateRequest;
import com.rideet.exception.BadRequestException;
import com.rideet.exception.ResourceNotFoundException;
import com.rideet.repository.DriverRepository;
import com.rideet.repository.UserRepository;
import com.rideet.websocket.RideWebSocketService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class DriverService {

    private final DriverRepository driverRepository;
    private final UserRepository userRepository;
    private final RideWebSocketService rideWebSocketService;

    @Transactional
    public Driver registerDriver(Long userId, Driver driverInfo) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        if (driverRepository.existsByUserId(userId)) {
            throw new BadRequestException("Driver profile already exists");
        }

        driverInfo.setUser(user);
        driverInfo.setStatus(DriverStatus.OFFLINE);
        return driverRepository.save(driverInfo);
    }

    @Transactional
    public Driver goOnline(Long userId) {
        Driver driver = getDriverByUserId(userId);
        if (!driver.isDocumentsVerified()) {
            throw new BadRequestException("Documents not verified yet");
        }
        driver.setStatus(DriverStatus.ONLINE);
        return driverRepository.save(driver);
    }

    @Transactional
    public Driver goOffline(Long userId) {
        Driver driver = getDriverByUserId(userId);
        if (driver.getStatus() == DriverStatus.ON_TRIP) {
            throw new BadRequestException("Cannot go offline while on a trip");
        }
        driver.setStatus(DriverStatus.OFFLINE);
        return driverRepository.save(driver);
    }

    @Transactional
    public void updateLocation(Long userId, LocationUpdateRequest request) {
        Driver driver = getDriverByUserId(userId);
        driver.setCurrentLatitude(request.getLatitude());
        driver.setCurrentLongitude(request.getLongitude());
        driver.setLastLocationUpdate(LocalDateTime.now());
        driverRepository.save(driver);

        // Broadcast location to any active passengers
        rideWebSocketService.broadcastDriverLocation(driver.getId(),
                request.getLatitude(), request.getLongitude(),
                request.getHeading(), request.getSpeed());
    }

    public Driver getDriverByUserId(Long userId) {
        return driverRepository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Driver profile not found"));
    }

    public Driver getDriverById(Long driverId) {
        return driverRepository.findById(driverId)
                .orElseThrow(() -> new ResourceNotFoundException("Driver not found"));
    }
}
