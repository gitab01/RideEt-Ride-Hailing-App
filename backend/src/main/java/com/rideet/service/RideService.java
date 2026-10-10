package com.rideet.service;

import com.rideet.common.GeoUtil;
import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.DriverLocation;
import com.rideet.domain.entity.Ride;
import com.rideet.domain.entity.User;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.PaymentMethod;
import com.rideet.domain.enums.RideStatus;
import com.rideet.dto.request.RatingRequest;
import com.rideet.dto.request.RideRequest;
import com.rideet.dto.response.FareEstimateResponse;
import com.rideet.dto.response.RideResponse;
import com.rideet.exception.BadRequestException;
import com.rideet.exception.ResourceNotFoundException;
import com.rideet.mapper.RideViewMapper;
import com.rideet.matching.DriverLocationIndex;
import com.rideet.matching.DriverPresenceCache;
import com.rideet.matching.LocationWriteBuffer;
import com.rideet.matching.MatchingService;
import com.rideet.matching.RideStateMachine;
import com.rideet.repository.DriverLocationRepository;
import com.rideet.repository.DriverRepository;
import com.rideet.repository.RideRepository;
import com.rideet.repository.UserRepository;
import com.rideet.websocket.RideWebSocketService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * Ride lifecycle. Every status change goes through {@link RideStateMachine}, so the
 * database holds both the current state (a column) and the story (an event table), and
 * no client can claim a transition the server would accept blindly.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RideService {

    private static final List<RideStatus> ACTIVE_STATUSES = List.of(
            RideStatus.REQUESTED, RideStatus.SEARCHING,
            RideStatus.DRIVER_ASSIGNED, RideStatus.DRIVER_ARRIVED, RideStatus.IN_PROGRESS);

    /** A driver must be within this of the pickup before a trip can start. */
    private static final double PICKUP_PROXIMITY_KM = 0.35;

    private final RideRepository rideRepository;
    private final DriverRepository driverRepository;
    private final DriverLocationRepository driverLocationRepository;
    private final UserRepository userRepository;
    private final FareCalculationService fareCalculationService;
    private final RideWebSocketService rideWebSocketService;
    private final NotificationService notificationService;
    private final RideStateMachine stateMachine;
    private final MatchingService matchingService;
    private final DriverLocationIndex locationIndex;
    private final DriverPresenceCache presenceCache;
    private final LocationWriteBuffer locationBuffer;
    private final RideViewMapper rideViewMapper;
    private final SecureRandom random = new SecureRandom();

    @Value("${fare.max-deviation-ratio:0.25}")
    private double maxDeviationRatio;

    @Transactional
    public RideResponse requestRide(Long passengerUserId, RideRequest request) {
        User passenger = userRepository.findById(passengerUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Passenger not found"));

        rideRepository.findFirstByPassengerIdAndStatusIn(passengerIdOf(passenger), ACTIVE_STATUSES)
                .ifPresent(r -> { throw new BadRequestException("You already have an active ride"); });

        double distance = fareCalculationService.calculateDistanceKm(
                request.getPickupLatitude(), request.getPickupLongitude(),
                request.getDestinationLatitude(), request.getDestinationLongitude());
        int duration = fareCalculationService.estimateDurationMinutes(distance);
        FareEstimateResponse estimate = fareCalculationService.calculateFare(distance, duration);

        // Nothing debits wallet_balance yet, so accepting it here would quietly bill the
        // ride through the card path instead.
        if (request.getPaymentMethod() == PaymentMethod.WALLET) {
            throw new BadRequestException("Wallet payments are not enabled yet — choose cash or card");
        }

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
                .estimatedFare(estimate.getEstimatedFare())
                .distanceKm(Math.round(distance * 100.0) / 100.0)
                .durationMinutes(duration)
                .surgeMultiplier(estimate.getSurgeMultiplier())
                .status(RideStatus.REQUESTED)
                .build();
        rideRepository.save(ride);

        stateMachine.transition(ride, RideStatus.SEARCHING, RideStateMachine.ACTOR_PASSENGER, "ride requested");
        rideRepository.save(ride);

        matchingService.startMatching(ride);
        rideWebSocketService.broadcastToAdmin("RIDE_REQUESTED", Map.of(
                "rideId", ride.getId(),
                "pickupLatitude", ride.getPickupLatitude(),
                "pickupLongitude", ride.getPickupLongitude()));
        log.info("Ride {} requested by user {}", ride.getId(), passengerUserId);

        return toResponse(ride, passengerUserId);
    }

    /**
     * A driver takes the ride. Delegates the winner election to the matching engine, then
     * tells the passenger who is coming.
     */
    @Transactional
    public RideResponse acceptRide(Long driverId, Long rideId) {
        Ride ride = matchingService.accept(driverId, rideId);
        return toResponse(ride, ride.getPassenger().getId());
    }

    @Transactional
    public void declineOffer(Long driverId, Long rideId) {
        matchingService.decline(driverId, rideId);
    }

    @Transactional
    public RideResponse markDriverArrived(Long driverId, Long rideId, Long viewerUserId) {
        Ride ride = getRideForDriver(driverId, rideId);
        stateMachine.transition(ride, RideStatus.DRIVER_ARRIVED, RideStateMachine.ACTOR_DRIVER, "at pickup");
        ride.setDriverArrivedAt(LocalDateTime.now());
        rideRepository.save(ride);

        rideWebSocketService.toPassenger(ride.getPassenger().getId(), "DRIVER_ARRIVED", rideId,
                toResponse(ride, ride.getPassenger().getId()));
        notificationService.sendPushNotification(ride.getPassenger().getId(), "Driver Arrived",
                "Your driver is waiting at the pickup point.");
        return toResponse(ride, viewerUserId);
    }

    /**
     * Trip start is driver-initiated but server-validated: the OTP proves the passenger
     * handed over the code, and the driver's live position proves they are actually at the
     * pickup point. Without the second check a spoofed client could start a fare anywhere.
     */
    @Transactional
    public RideResponse startRide(Long driverId, Long rideId, String otp) {
        Ride ride = getRideForDriver(driverId, rideId);
        if (ride.getRideStartOtp() == null || !ride.getRideStartOtp().equals(otp)) {
            throw new BadRequestException("Invalid start code");
        }
        requireDriverAtPickup(driverId, ride);

        stateMachine.transition(ride, RideStatus.IN_PROGRESS, RideStateMachine.ACTOR_DRIVER, "trip started");
        ride.setStartedAt(LocalDateTime.now());
        rideRepository.save(ride);

        rideWebSocketService.toPassenger(ride.getPassenger().getId(), "RIDE_STARTED", rideId,
                toResponse(ride, ride.getPassenger().getId()));
        return toResponse(ride, ride.getDriver().getUser().getId());
    }

    @Transactional
    public RideResponse completeRide(Long driverId, Long rideId) {
        Ride ride = getRideForDriver(driverId, rideId);
        stateMachine.transition(ride, RideStatus.COMPLETED, RideStateMachine.ACTOR_DRIVER, "trip finished");

        LocalDateTime endedAt = LocalDateTime.now();
        locationBuffer.flushNow();
        ActualTrip actual = measureActualTrip(ride, driverId, endedAt);

        FareEstimateResponse recomputed = fareCalculationService.calculateFare(
                actual.distanceKm(), actual.durationMinutes());
        double finalFare = capToFareWindow(recomputed.getEstimatedFare(), ride.getEstimatedFare());

        ride.setActualFare(finalFare);
        ride.setDistanceKm(Math.round(actual.distanceKm() * 100.0) / 100.0);
        ride.setDurationMinutes(actual.durationMinutes());
        ride.setCompletedAt(endedAt);

        Driver driver = ride.getDriver();
        driver.setStatus(DriverStatus.ONLINE);
        driver.setTotalRides(driver.getTotalRides() + 1);
        driver.setTotalEarnings(round2(driver.getTotalEarnings() + finalFare));
        driverRepository.save(driver);
        presenceCache.statusChanged(driver.getUser().getId(), DriverStatus.ONLINE);
        if (actual.distanceKm() > 0 && driver.getCurrentLatitude() != null) {
            locationIndex.put(driver.getId(), driver.getUser().getId(),
                    driver.getCurrentLatitude(), driver.getCurrentLongitude(), driver.getVehicleType());
        }
        rideRepository.save(ride);

        rideWebSocketService.toPassenger(ride.getPassenger().getId(), "RIDE_COMPLETED", rideId,
                toResponse(ride, ride.getPassenger().getId()));
        notificationService.sendPushNotification(ride.getPassenger().getId(), "Ride Completed",
                "Your ride is complete. Total fare: " + finalFare);
        log.info("Ride {} completed: quoted {}, charged {} over {} km",
                rideId, ride.getEstimatedFare(), finalFare, ride.getDistanceKm());

        return toResponse(ride, driver.getUser().getId());
    }

    /**
     * @param actorUserId the passenger's or driver's app-user id requesting the cancellation
     * @param actor       {@link RideStateMachine#ACTOR_PASSENGER} or {@link RideStateMachine#ACTOR_DRIVER}
     */
    @Transactional
    public RideResponse cancelRide(Long actorUserId, Long rideId, String reason, String actor) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

        boolean isPassenger = ride.getPassenger().getId().equals(actorUserId);
        boolean isDriver = ride.getDriver() != null
                && ride.getDriver().getUser().getId().equals(actorUserId);
        if (!isPassenger && !isDriver) {
            throw new BadRequestException("Only the rider or the assigned driver can cancel this ride");
        }

        boolean driverQuitMidRide = RideStateMachine.ACTOR_DRIVER.equals(actor) && ride.getDriver() != null;

        if (driverQuitMidRide) {
            // A driver backing out is the rider's problem to solve, not the rider's loss:
            // hand the ride straight back to the pool rather than cancelling it.
            Driver withdrawn = releaseDriver(ride);
            matchingService.closeRound(rideId, "DRIVER_CANCELLED");
            stateMachine.transition(ride, RideStatus.SEARCHING, actor,
                    "driver cancelled" + (reason == null ? "" : ": " + reason));
            ride.setDriver(null);
            ride.setDriverAssignedAt(null);
            ride.setDriverArrivedAt(null);
            ride.setRideStartOtp(null);
            rideRepository.save(ride);
            matchingService.startMatching(ride);

            rideWebSocketService.toPassenger(ride.getPassenger().getId(), "DRIVER_CANCELLED", rideId,
                    Map.of("reason", reason == null ? "" : reason, "rematching", true));
            log.info("Ride {} returned to the pool after driver {} cancelled", rideId, withdrawn.getId());
            return toResponse(ride, actorUserId);
        }

        if (!RideStateMachine.allowedFrom(ride.getStatus()).contains(RideStatus.CANCELLED)) {
            throw new BadRequestException("Ride cannot be cancelled at this stage");
        }

        matchingService.closeRound(rideId, "CANCELLED");
        Long driverUserId = ride.getDriver() == null ? null : ride.getDriver().getUser().getId();
        if (ride.getDriver() != null) releaseDriver(ride);

        stateMachine.transition(ride, RideStatus.CANCELLED, actor, reason);
        ride.setCancelledAt(LocalDateTime.now());
        ride.setCancellationReason(reason);
        ride.setCancelledBy(actor);
        rideRepository.save(ride);

        Map<String, Object> cancelled = Map.of(
                "by", actor, "reason", reason == null ? "" : reason);
        if (!isPassenger) {
            rideWebSocketService.toPassenger(ride.getPassenger().getId(), "RIDE_CANCELLED", rideId, cancelled);
        }
        if (driverUserId != null) {
            rideWebSocketService.toDriver(driverUserId, "RIDE_CANCELLED", rideId, cancelled);
        }
        return toResponse(ride, actorUserId);
    }

    /** Put a driver back on the market and stop them being offered work they cannot take. */
    private Driver releaseDriver(Ride ride) {
        Driver driver = ride.getDriver();
        if (driver == null) return null;
        driver.setStatus(DriverStatus.ONLINE);
        driverRepository.save(driver);
        presenceCache.statusChanged(driver.getUser().getId(), DriverStatus.ONLINE);
        if (driver.getCurrentLatitude() != null && driver.getCurrentLongitude() != null) {
            locationIndex.put(driver.getId(), driver.getUser().getId(),
                    driver.getCurrentLatitude(), driver.getCurrentLongitude(), driver.getVehicleType());
        }
        return driver;
    }

    /** Two-sided feedback: either party rates the other once, after the ride is complete. */
    @Transactional
    public void rateRide(Long actorUserId, Long rideId, RatingRequest request) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

        if (ride.getStatus() != RideStatus.COMPLETED) {
            throw new BadRequestException("Only a completed ride can be rated");
        }
        boolean byPassenger = ride.getPassenger().getId().equals(actorUserId);
        boolean byDriver = ride.getDriver() != null && ride.getDriver().getUser().getId().equals(actorUserId);
        if (!byPassenger && !byDriver) {
            throw new BadRequestException("Only a participant can rate this ride");
        }
        if (byPassenger && ride.getPassengerRating() != null) {
            throw new BadRequestException("Rating already submitted");
        }
        if (byDriver && ride.getDriverRating() != null) {
            throw new BadRequestException("Rating already submitted");
        }

        if (byPassenger) {
            ride.setPassengerRating(request.getRating());
            ride.setPassengerReview(request.getReview());
            Driver driver = ride.getDriver();
            driver.setRating(round2(((driver.getRating() * driver.getTotalRatings()) + request.getRating())
                    / (driver.getTotalRatings() + 1)));
            driver.setTotalRatings(driver.getTotalRatings() + 1);
            driverRepository.save(driver);
        } else {
            ride.setDriverRating(request.getRating());
            ride.setDriverReview(request.getReview());
            User passenger = ride.getPassenger();
            passenger.setRating(round2(((passenger.getRating() * passenger.getTotalRatings()) + request.getRating())
                    / (passenger.getTotalRatings() + 1)));
            passenger.setTotalRatings(passenger.getTotalRatings() + 1);
            userRepository.save(passenger);
        }
        rideRepository.save(ride);
    }

    public FareEstimateResponse estimateFare(double pickupLat, double pickupLng,
                                             double destLat, double destLng) {
        double distance = fareCalculationService.calculateDistanceKm(pickupLat, pickupLng, destLat, destLng);
        int duration = fareCalculationService.estimateDurationMinutes(distance);
        return fareCalculationService.calculateFare(distance, duration);
    }

    @Transactional(readOnly = true)
    public Page<RideResponse> getPassengerHistory(Long passengerUserId, Pageable pageable) {
        return rideRepository.findByPassengerIdOrderByCreatedAtDesc(passengerUserId, pageable)
                .map(ride -> toResponse(ride, passengerUserId));
    }

    @Transactional(readOnly = true)
    public Page<RideResponse> getDriverHistory(Long driverId, Pageable pageable) {
        return rideRepository.findByDriverIdOrderByCreatedAtDesc(driverId, pageable)
                .map(ride -> toResponse(ride, null));
    }

    /**
     * Authoritative state for a reconnecting client. A participant gets the full view;
     * anyone else is refused, because a ride's pickup and drop-off points are personal data.
     */
    @Transactional(readOnly = true)
    public RideResponse getRideForUser(Long userId, Long rideId) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));
        boolean participant = ride.getPassenger().getId().equals(userId)
                || (ride.getDriver() != null && ride.getDriver().getUser().getId().equals(userId));
        if (!participant) {
            throw new BadRequestException("You are not a participant of this ride");
        }
        return toResponse(ride, userId);
    }

    @Transactional(readOnly = true)
    public List<RideResponse> getActiveRideForUser(Long userId) {
        return rideRepository.findByStatusIn(ACTIVE_STATUSES).stream()
                .filter(r -> r.getPassenger().getId().equals(userId)
                        || (r.getDriver() != null && r.getDriver().getUser().getId().equals(userId)))
                .map(r -> toResponse(r, userId))
                .toList();
    }

    private Ride getRideForDriver(Long driverId, Long rideId) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));
        if (ride.getDriver() == null || !ride.getDriver().getId().equals(driverId)) {
            throw new BadRequestException("This ride is not assigned to you");
        }
        return ride;
    }

    private void requireDriverAtPickup(Long driverId, Ride ride) {
        double[] position = livePositionOf(driverId, ride);
        if (position == null) {
            throw new BadRequestException("No live location for this driver; keep the app in the foreground");
        }
        double off = GeoUtil.kmBetween(ride.getPickupLatitude(), ride.getPickupLongitude(),
                position[0], position[1]);
        if (off > PICKUP_PROXIMITY_KM) {
            throw new BadRequestException(
                    String.format("You must be within %d m of the pickup point", (int) (PICKUP_PROXIMITY_KM * 1000)));
        }
    }

    /** Live index first (fresh to within one ping), durable last-known position as fallback. */
    private double[] livePositionOf(Long driverId, Ride ride) {
        return locationIndex.placementOf(driverId)
                .map(p -> new double[]{p.latitude(), p.longitude()})
                .orElseGet(() -> {
                    Driver d = ride.getDriver();
                    if (d == null || d.getCurrentLatitude() == null) return null;
                    return new double[]{d.getCurrentLatitude(), d.getCurrentLongitude()};
                });
    }

    /**
     * Actual distance travelled, summed from the flushed position trail. Falls back to the
     * straight-line route when a trip was too short to have produced pings.
     */
    private ActualTrip measureActualTrip(Ride ride, Long driverId, LocalDateTime endedAt) {
        int durationMinutes = ride.getStartedAt() == null ? 0
                : Math.max(1, (int) Math.ceil(Duration.between(ride.getStartedAt(), endedAt).toMinutes()));

        List<DriverLocation> trail = driverLocationRepository
                .findByDriverIdAndRecordedAtBetweenOrderByRecordedAtAsc(driverId, ride.getStartedAt(), endedAt);

        double travelled = 0.0;
        for (int i = 1; i < trail.size(); i++) {
            DriverLocation a = trail.get(i - 1);
            DriverLocation b = trail.get(i);
            travelled += GeoUtil.kmBetween(a.getLatitude(), a.getLongitude(), b.getLatitude(), b.getLongitude());
        }
        if (travelled <= 0.0) {
            travelled = GeoUtil.kmBetween(ride.getPickupLatitude(), ride.getPickupLongitude(),
                    ride.getDestinationLatitude(), ride.getDestinationLongitude());
        }
        return new ActualTrip(Math.round(travelled * 100.0) / 100.0, durationMinutes);
    }

    /**
     * Price certainty both ways: the driver is paid for the road actually driven, but the
     * passenger is never charged more than the agreed window around the quote.
     */
    private double capToFareWindow(double computed, Double quoted) {
        if (quoted == null || quoted <= 0) return round2(computed);
        double ceiling = quoted * (1 + maxDeviationRatio);
        double floor = quoted * (1 - maxDeviationRatio);
        return round2(Math.min(Math.max(computed, floor), ceiling));
    }

    private Long passengerIdOf(User user) {
        return user.getId();
    }

    private static double round2(double value) {
        return Math.round(value * 100.0) / 100.0;
    }

    private record ActualTrip(double distanceKm, int durationMinutes) {
    }

    /**
     * @param viewerUserId the requesting user; the start code is only ever sent to the
     *                     passenger, since a driver who could read it would not need to ask.
     */
    public RideResponse toResponse(Ride ride, Long viewerUserId) {
        return rideViewMapper.toResponse(ride, viewerUserId);
    }
}
