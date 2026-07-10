package com.rideet.service;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.Ride;
import com.rideet.domain.entity.User;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.RideStatus;
import com.rideet.dto.request.RatingRequest;
import com.rideet.dto.request.RideRequest;
import com.rideet.dto.response.FareEstimateResponse;
import com.rideet.dto.response.RideResponse;
import com.rideet.exception.BadRequestException;
import com.rideet.exception.ResourceNotFoundException;
import com.rideet.repository.DriverRepository;
import com.rideet.repository.RideRepository;
import com.rideet.repository.UserRepository;
import com.rideet.websocket.RideWebSocketService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Random;

@Service
@RequiredArgsConstructor
@Slf4j
public class RideService {

    private final RideRepository rideRepository;
    private final DriverRepository driverRepository;
    private final UserRepository userRepository;
    private final FareCalculationService fareCalculationService;
    private final RideWebSocketService rideWebSocketService;
    private final NotificationService notificationService;

    @Transactional
    public RideResponse requestRide(Long passengerId, RideRequest request) {
        User passenger = userRepository.findById(passengerId)
                .orElseThrow(() -> new ResourceNotFoundException("Passenger not found"));

        // Check no active ride exists
        List<RideStatus> activeStatuses = List.of(
                RideStatus.REQUESTED, RideStatus.SEARCHING,
                RideStatus.DRIVER_ASSIGNED, RideStatus.DRIVER_ARRIVED, RideStatus.IN_PROGRESS
        );
        rideRepository.findFirstByPassengerIdAndStatusIn(passengerId, activeStatuses)
                .ifPresent(r -> { throw new BadRequestException("You already have an active ride"); });

        // Calculate fare estimate
        double distance = fareCalculationService.calculateDistanceKm(
                request.getPickupLatitude(), request.getPickupLongitude(),
                request.getDestinationLatitude(), request.getDestinationLongitude()
        );
        int duration = fareCalculationService.estimateDurationMinutes(distance);
        FareEstimateResponse fareEstimate = fareCalculationService.calculateFare(distance, duration);

        Ride ride = Ride.builder()
                .passenger(passenger)
                .pickupAddress(request.getPickupAddress())
                .pickupLatitude(request.getPickupLatitude())
                .pickupLongitude(request.getPickupLongitude())
                .destinationAddress(request.getDestinationAddress())
                .destinationLatitude(request.getDestinationLatitude())
                .destinationLongitude(request.getDestinationLongitude())
                .vehicleType(request.getVehicleType())
                .paymentMethod(request.getPaymentMethod())
                .estimatedFare(fareEstimate.getEstimatedFare())
                .distanceKm(distance)
                .durationMinutes(duration)
                .status(RideStatus.SEARCHING)
                .build();

        rideRepository.save(ride);
        log.info("Ride requested: {} by passenger {}", ride.getId(), passengerId);

        // Async driver matching
        matchDriver(ride);

        return mapToResponse(ride);
    }

    @Async
    public void matchDriver(Ride ride) {
        List<Driver> nearbyDrivers = driverRepository.findNearbyOnlineDrivers(
                ride.getPickupLatitude(), ride.getPickupLongitude(),
                10.0, ride.getVehicleType().name()
        );

        if (nearbyDrivers.isEmpty()) {
            ride.setStatus(RideStatus.NO_DRIVER_FOUND);
            rideRepository.save(ride);
            rideWebSocketService.notifyPassenger(ride.getPassenger().getId(), "NO_DRIVER_FOUND", ride.getId());
            return;
        }

        // Notify up to 3 nearest drivers
        nearbyDrivers.stream().limit(3).forEach(driver ->
                rideWebSocketService.notifyDriver(driver.getId(), "RIDE_REQUEST", ride.getId())
        );
    }

    @Transactional
    public RideResponse acceptRide(Long driverId, Long rideId) {
        Driver driver = driverRepository.findById(driverId)
                .orElseThrow(() -> new ResourceNotFoundException("Driver not found"));

        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

        if (ride.getStatus() != RideStatus.SEARCHING) {
            throw new BadRequestException("Ride is no longer available");
        }
        if (driver.getStatus() != DriverStatus.ONLINE) {
            throw new BadRequestException("Driver is not available");
        }

        ride.setDriver(driver);
        ride.setStatus(RideStatus.DRIVER_ASSIGNED);
        ride.setDriverAssignedAt(LocalDateTime.now());
        ride.setRideStartOtp(generateOtp());
        driver.setStatus(DriverStatus.ON_TRIP);

        rideRepository.save(ride);
        driverRepository.save(driver);

        rideWebSocketService.notifyPassenger(ride.getPassenger().getId(), "DRIVER_ASSIGNED", rideId);
        notificationService.sendPushNotification(
                ride.getPassenger().getId(),
                "Driver Found!",
                driver.getUser().getFullName() + " is on the way. " + driver.getVehicleColor() + " " + driver.getVehicleMake()
        );

        return mapToResponse(ride);
    }

    @Transactional
    public RideResponse markDriverArrived(Long driverId, Long rideId) {
        Ride ride = getRideForDriver(driverId, rideId);
        if (ride.getStatus() != RideStatus.DRIVER_ASSIGNED) {
            throw new BadRequestException("Invalid ride status");
        }
        ride.setStatus(RideStatus.DRIVER_ARRIVED);
        ride.setDriverArrivedAt(LocalDateTime.now());
        rideRepository.save(ride);

        rideWebSocketService.notifyPassenger(ride.getPassenger().getId(), "DRIVER_ARRIVED", rideId);
        notificationService.sendPushNotification(ride.getPassenger().getId(), "Driver Arrived", "Your driver has arrived at the pickup location.");

        return mapToResponse(ride);
    }

    @Transactional
    public RideResponse startRide(Long driverId, Long rideId, String otp) {
        Ride ride = getRideForDriver(driverId, rideId);
        if (ride.getStatus() != RideStatus.DRIVER_ARRIVED) {
            throw new BadRequestException("Driver must be at pickup location");
        }
        if (!ride.getRideStartOtp().equals(otp)) {
            throw new BadRequestException("Invalid OTP");
        }

        ride.setStatus(RideStatus.IN_PROGRESS);
        ride.setStartedAt(LocalDateTime.now());
        rideRepository.save(ride);

        rideWebSocketService.notifyPassenger(ride.getPassenger().getId(), "RIDE_STARTED", rideId);
        return mapToResponse(ride);
    }

    @Transactional
    public RideResponse completeRide(Long driverId, Long rideId) {
        Ride ride = getRideForDriver(driverId, rideId);
        if (ride.getStatus() != RideStatus.IN_PROGRESS) {
            throw new BadRequestException("Ride is not in progress");
        }

        ride.setStatus(RideStatus.COMPLETED);
        ride.setCompletedAt(LocalDateTime.now());
        ride.setActualFare(ride.getEstimatedFare());

        Driver driver = ride.getDriver();
        driver.setStatus(DriverStatus.ONLINE);
        driver.setTotalRides(driver.getTotalRides() + 1);
        driver.setTotalEarnings(driver.getTotalEarnings() + ride.getActualFare());

        rideRepository.save(ride);
        driverRepository.save(driver);

        rideWebSocketService.notifyPassenger(ride.getPassenger().getId(), "RIDE_COMPLETED", rideId);
        notificationService.sendPushNotification(
                ride.getPassenger().getId(),
                "Ride Completed",
                "Your ride is complete. Total fare: $" + ride.getActualFare()
        );

        return mapToResponse(ride);
    }

    @Transactional
    public RideResponse cancelRide(Long userId, Long rideId, String reason, String cancelledBy) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

        List<RideStatus> cancellableStatuses = List.of(
                RideStatus.SEARCHING, RideStatus.DRIVER_ASSIGNED, RideStatus.DRIVER_ARRIVED
        );
        if (!cancellableStatuses.contains(ride.getStatus())) {
            throw new BadRequestException("Ride cannot be cancelled at this stage");
        }

        ride.setStatus(RideStatus.CANCELLED);
        ride.setCancelledAt(LocalDateTime.now());
        ride.setCancellationReason(reason);
        ride.setCancelledBy(cancelledBy);

        if (ride.getDriver() != null) {
            Driver driver = ride.getDriver();
            driver.setStatus(DriverStatus.ONLINE);
            driverRepository.save(driver);
        }

        rideRepository.save(ride);

        if ("PASSENGER".equals(cancelledBy) && ride.getDriver() != null) {
            rideWebSocketService.notifyDriver(ride.getDriver().getId(), "RIDE_CANCELLED", rideId);
        } else if ("DRIVER".equals(cancelledBy)) {
            rideWebSocketService.notifyPassenger(ride.getPassenger().getId(), "RIDE_CANCELLED", rideId);
            matchDriver(ride); // Try to find another driver
        }

        return mapToResponse(ride);
    }

    @Transactional
    public void rateDriver(Long passengerId, Long rideId, RatingRequest request) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

        if (!ride.getPassenger().getId().equals(passengerId)) {
            throw new BadRequestException("Unauthorized");
        }
        if (ride.getStatus() != RideStatus.COMPLETED) {
            throw new BadRequestException("Ride must be completed before rating");
        }
        if (ride.getPassengerRating() != null) {
            throw new BadRequestException("Rating already submitted");
        }

        ride.setPassengerRating(request.getRating());
        ride.setPassengerReview(request.getReview());
        rideRepository.save(ride);

        // Update driver average rating
        Driver driver = ride.getDriver();
        double newRating = ((driver.getRating() * driver.getTotalRatings()) + request.getRating())
                / (driver.getTotalRatings() + 1);
        driver.setRating(Math.round(newRating * 10.0) / 10.0);
        driver.setTotalRatings(driver.getTotalRatings() + 1);
        driverRepository.save(driver);
    }

    public FareEstimateResponse estimateFare(double pickupLat, double pickupLng,
                                              double destLat, double destLng) {
        double distance = fareCalculationService.calculateDistanceKm(pickupLat, pickupLng, destLat, destLng);
        int duration = fareCalculationService.estimateDurationMinutes(distance);
        return fareCalculationService.calculateFare(distance, duration);
    }

    public Page<RideResponse> getPassengerHistory(Long passengerId, Pageable pageable) {
        return rideRepository.findByPassengerIdOrderByCreatedAtDesc(passengerId, pageable)
                .map(this::mapToResponse);
    }

    public Page<RideResponse> getDriverHistory(Long driverId, Pageable pageable) {
        return rideRepository.findByDriverIdOrderByCreatedAtDesc(driverId, pageable)
                .map(this::mapToResponse);
    }

    public RideResponse getRideById(Long rideId) {
        return rideRepository.findById(rideId)
                .map(this::mapToResponse)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));
    }

    private Ride getRideForDriver(Long driverId, Long rideId) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));
        if (ride.getDriver() == null || !ride.getDriver().getId().equals(driverId)) {
            throw new BadRequestException("Unauthorized");
        }
        return ride;
    }

    private String generateOtp() {
        return String.format("%06d", new Random().nextInt(999999));
    }

    private RideResponse mapToResponse(Ride ride) {
        RideResponse.RideResponseBuilder builder = RideResponse.builder()
                .id(ride.getId())
                .passengerId(ride.getPassenger().getId())
                .passengerName(ride.getPassenger().getFullName())
                .pickupAddress(ride.getPickupAddress())
                .pickupLatitude(ride.getPickupLatitude())
                .pickupLongitude(ride.getPickupLongitude())
                .destinationAddress(ride.getDestinationAddress())
                .destinationLatitude(ride.getDestinationLatitude())
                .destinationLongitude(ride.getDestinationLongitude())
                .vehicleType(ride.getVehicleType())
                .status(ride.getStatus())
                .estimatedFare(ride.getEstimatedFare())
                .actualFare(ride.getActualFare())
                .distanceKm(ride.getDistanceKm())
                .durationMinutes(ride.getDurationMinutes())
                .paymentMethod(ride.getPaymentMethod())
                .requestedAt(ride.getRequestedAt())
                .driverAssignedAt(ride.getDriverAssignedAt())
                .startedAt(ride.getStartedAt())
                .completedAt(ride.getCompletedAt());

        if (ride.getDriver() != null) {
            Driver driver = ride.getDriver();
            builder.driverId(driver.getId())
                    .driverName(driver.getUser().getFullName())
                    .driverPhone(driver.getUser().getPhone())
                    .driverProfilePicture(driver.getUser().getProfilePictureUrl())
                    .driverRating(driver.getRating())
                    .vehicleMake(driver.getVehicleMake())
                    .vehicleModel(driver.getVehicleModel())
                    .licensePlate(driver.getLicensePlate())
                    .vehicleColor(driver.getVehicleColor());
        }

        return builder.build();
    }
}
