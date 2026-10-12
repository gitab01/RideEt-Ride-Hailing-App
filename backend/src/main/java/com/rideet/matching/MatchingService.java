package com.rideet.matching;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.Ride;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.RideStatus;
import com.rideet.domain.enums.VehicleType;
import com.rideet.dto.response.FareEstimateResponse;
import com.rideet.dto.response.RideOfferResponse;
import com.rideet.exception.BadRequestException;
import com.rideet.exception.ResourceNotFoundException;
import com.rideet.mapper.RideViewMapper;
import com.rideet.repository.DriverRepository;
import com.rideet.repository.RideRepository;
import com.rideet.service.FareCalculationService;
import com.rideet.websocket.RideWebSocketService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Nearest-first matching with a bounded, expanding offer radius.
 *
 * <p>A ride in {@code SEARCHING} gets a round: the nearest available drivers each receive
 * an offer carrying a deadline. When a round expires unanswered the radius widens and the
 * offer re-broadcasts to drivers not yet asked, which keeps dense areas fast and sparse
 * areas reachable. Acceptance is a compare-and-set on ride status, so of two drivers who
 * tap accept in the same millisecond exactly one gets the ride and the other is told so
 * immediately.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class MatchingService {

    /** One in-flight offer round for one ride. Held in memory on purpose. */
    private static final class Round {
        final Long rideId;
        final Long passengerId;
        final Long passengerUserId;
        final double pickupLat;
        final double pickupLng;
        final VehicleType vehicleType;
        final Set<Long> offeredDrivers = new HashSet<>();
        final Set<Long> offeredUserIds = new HashSet<>();
        double radiusKm;
        Instant expiresAt;
        int roundNumber;

        Round(Long rideId, Long passengerId, Long passengerUserId, double pickupLat, double pickupLng,
              VehicleType vehicleType, double radiusKm) {
            this.rideId = rideId;
            this.passengerId = passengerId;
            this.passengerUserId = passengerUserId;
            this.pickupLat = pickupLat;
            this.pickupLng = pickupLng;
            this.vehicleType = vehicleType;
            this.radiusKm = radiusKm;
        }
    }

    private final Map<Long, Round> rounds = new ConcurrentHashMap<>();
    private final SecureRandom random = new SecureRandom();

    private final DriverLocationIndex locationIndex;
    private final DriverPresenceCache presenceCache;
    private final RideRepository rideRepository;
    private final DriverRepository driverRepository;
    private final RideStateMachine stateMachine;
    private final RideWebSocketService webSocketService;
    private final RideViewMapper rideViewMapper;
    private final FareCalculationService fareCalculationService;

    @Value("${matching.max-radius-km:12.0}")
    private double maxRadiusKm;

    @Value("${matching.offer-window-seconds:20}")
    private int offerWindowSeconds;

    @Value("${matching.candidates-per-round:5}")
    private int candidatesPerRound;

    public boolean isMatching(Long rideId) {
        return rounds.containsKey(rideId);
    }

    /**
     * Begin offering a freshly created ride. Called inside the caller's transaction so a
     * ride that never commits can never be offered.
     */
    public void startMatching(Ride ride) {
        Round round = new Round(ride.getId(), ride.getPassenger().getId(),
                ride.getPassenger().getId(), ride.getPickupLatitude(), ride.getPickupLongitude(),
                ride.getVehicleType(), locationIndexRadiusStart());
        round.roundNumber = 1;
        rounds.put(ride.getId(), round);
        broadcastOffers(ride, round);
    }

    private double locationIndexRadiusStart() {
        return Math.min(maxRadiusKm, 2.0);
    }

    private void broadcastOffers(Ride ride, Round round) {
        List<DriverLocationIndex.Candidate> nearby = locationIndex.nearest(
                round.pickupLat, round.pickupLng, round.radiusKm,
                round.vehicleType, round.offeredDrivers, 0);

        List<DriverLocationIndex.Candidate> candidates = new ArrayList<>();
        for (DriverLocationIndex.Candidate candidate : nearby) {
            if (candidates.size() >= candidatesPerRound) break;
            if (!isFreeForMatching(candidate.userId())) continue;
            candidates.add(candidate);
        }

        if (candidates.isEmpty()) {
            log.debug("Ride {} round {}: no free driver inside {} km",
                    round.rideId, round.roundNumber, round.radiusKm);
            round.expiresAt = Instant.now().plusSeconds(offerWindowSeconds);
            return;
        }

        round.expiresAt = Instant.now().plusSeconds(offerWindowSeconds);
        for (DriverLocationIndex.Candidate candidate : candidates) {
            round.offeredDrivers.add(candidate.driverId());
            round.offeredUserIds.add(candidate.userId());
            webSocketService.toDriver(candidate.userId(), "RIDE_OFFER", round.rideId,
                    buildOffer(ride, candidate, round));
        }
        webSocketService.toPassenger(round.passengerUserId, "SEARCHING_DRIVERS", round.rideId,
                Map.of("round", round.roundNumber, "driversContacted", round.offeredDrivers.size(),
                        "radiusKm", round.radiusKm));
        log.info("Ride {} round {}: offered to {} drivers within {} km",
                round.rideId, round.roundNumber, candidates.size(), round.radiusKm);
    }

    private RideOfferResponse buildOffer(Ride ride, DriverLocationIndex.Candidate candidate, Round round) {
        return RideOfferResponse.builder()
                .rideId(ride.getId())
                .passengerId(ride.getPassenger().getId())
                .passengerName(ride.getPassenger().getFullName())
                .pickupAddress(ride.getPickupAddress())
                .pickupLatitude(ride.getPickupLatitude())
                .pickupLongitude(ride.getPickupLongitude())
                .destinationAddress(ride.getDestinationAddress())
                .destinationLatitude(ride.getDestinationLatitude())
                .destinationLongitude(ride.getDestinationLongitude())
                .vehicleType(ride.getVehicleType())
                .estimatedFare(ride.getEstimatedFare())
                .distanceToPickupKm(Math.round(candidate.distanceKm() * 100.0) / 100.0)
                .durationMinutes(ride.getDurationMinutes())
                .expiresAt(LocalDateTime.ofInstant(round.expiresAt, ZoneId.systemDefault()))
                .offerWindowSeconds(offerWindowSeconds)
                .build();
    }

    /**
     * First accept wins. The status compare-and-set is the arbiter: exactly one caller
     * moves the ride out of {@code SEARCHING}.
     */
    @Transactional
    public Ride accept(Long driverId, Long rideId) {
        int won = rideRepository.compareAndSetStatus(rideId, RideStatus.SEARCHING, RideStatus.DRIVER_ASSIGNED);
        if (won == 0) {
            throw new BadRequestException("This ride is no longer available");
        }

        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));
        Driver driver = driverRepository.findByIdWithUser(driverId)
                .orElseThrow(() -> new ResourceNotFoundException("Driver not found"));

        boolean wrongClass = driver.getVehicleType() != ride.getVehicleType();
        if (driver.getStatus() != DriverStatus.ONLINE || !driver.isDocumentsVerified() || wrongClass) {
            // Undo our own claim: the ride goes back to the pool rather than dying assigned.
            rideRepository.compareAndSetStatus(rideId, RideStatus.DRIVER_ASSIGNED, RideStatus.SEARCHING);
            throw new BadRequestException(wrongClass
                    ? "This ride is not for your vehicle class"
                    : "Driver is not available");
        }

        ride.setDriver(driver);
        ride.setDriverAssignedAt(LocalDateTime.now());
        ride.setRideStartOtp(String.format("%06d", random.nextInt(1_000_000)));
        driver.setStatus(DriverStatus.ON_TRIP);
        driver.setOffersAccepted(driver.getOffersAccepted() + 1);
        driverRepository.save(driver);
        rideRepository.save(ride);

        stateMachine.recordTransition(ride, RideStatus.SEARCHING, RideStatus.DRIVER_ASSIGNED, RideStateMachine.ACTOR_DRIVER,
                "driver " + driverId + " accepted");
        presenceCache.statusChanged(driver.getUser().getId(), DriverStatus.ON_TRIP);
        closeRound(rideId, "ACCEPTED");

        webSocketService.toPassenger(ride.getPassenger().getId(), "DRIVER_ASSIGNED", rideId,
                rideViewMapper.toResponse(ride, ride.getPassenger().getId()));
        webSocketService.broadcastToAdmin("RIDE_ASSIGNED", Map.of("rideId", rideId, "driverId", driverId));
        log.info("Ride {} accepted by driver {}", rideId, driverId);
        return ride;
    }

    /**
     * Manual dispatch from the admin console. The ride is claimed with the same compare-and-set
     * as {@link #accept}, so an admin override and a driver tapping accept cannot both win.
     *
     * <p>Unlike a driver-initiated accept, a different vehicle class is allowed here — sending the
     * only car that is free is the point of dispatch — so the ride is re-tiered to the vehicle that
     * is actually coming and re-quoted from that tier's pricing. The rider is charged for the car
     * they get, not for the car they asked for, and is told about it.
     */
    @Transactional
    public Ride adminAssign(Long driverId, Long rideId) {
        int won = rideRepository.compareAndSetStatus(rideId, RideStatus.SEARCHING, RideStatus.DRIVER_ASSIGNED);
        if (won == 0) {
            throw new BadRequestException("This ride is not waiting for a driver");
        }

        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));
        Driver driver = driverRepository.findByIdWithUser(driverId)
                .orElseThrow(() -> new ResourceNotFoundException("Driver not found"));

        if (driver.getStatus() != DriverStatus.ONLINE || !driver.isDocumentsVerified()) {
            rideRepository.compareAndSetStatus(rideId, RideStatus.DRIVER_ASSIGNED, RideStatus.SEARCHING);
            throw new BadRequestException(driver.getStatus() != DriverStatus.ONLINE
                    ? "Driver is not available (status " + driver.getStatus() + ")"
                    : "Driver documents are not approved");
        }

        VehicleType requested = ride.getVehicleType();
        boolean reTiered = driver.getVehicleType() != requested;
        if (reTiered) {
            double distanceKm = ride.getDistanceKm() != null ? ride.getDistanceKm() : 0.0;
            int durationMinutes = ride.getDurationMinutes() != null ? ride.getDurationMinutes() : 0;
            FareEstimateResponse requote = fareCalculationService.calculateFare(
                    distanceKm, durationMinutes, driver.getVehicleType());
            ride.setVehicleType(driver.getVehicleType());
            ride.setEstimatedFare(requote.getEstimatedFare());
            ride.setSurgeMultiplier(requote.getSurgeMultiplier());
        }

        ride.setDriver(driver);
        ride.setDriverAssignedAt(LocalDateTime.now());
        ride.setRideStartOtp(String.format("%06d", random.nextInt(1_000_000)));
        driver.setStatus(DriverStatus.ON_TRIP);
        driver.setOffersAccepted(driver.getOffersAccepted() + 1);
        driverRepository.save(driver);
        rideRepository.save(ride);

        stateMachine.recordTransition(ride, RideStatus.SEARCHING, RideStatus.DRIVER_ASSIGNED,
                RideStateMachine.ACTOR_SYSTEM,
                "admin dispatch to driver " + driverId + (reTiered
                        ? " (re-tiered " + requested + " -> " + driver.getVehicleType() + ")"
                        : ""));
        presenceCache.statusChanged(driver.getUser().getId(), DriverStatus.ON_TRIP);
        closeRound(rideId, "ADMIN_ASSIGNED");

        if (reTiered) {
            webSocketService.toPassenger(ride.getPassenger().getId(), "RIDE_REQUOTED", rideId,
                    rideViewMapper.toResponse(ride, ride.getPassenger().getId()));
        }
        // Not an offer: the ride is already theirs, so the driver app opens it as the current trip.
        webSocketService.toDriver(driver.getUser().getId(), "RIDE_ASSIGNED", rideId,
                rideViewMapper.toResponse(ride, driver.getUser().getId()));
        webSocketService.toPassenger(ride.getPassenger().getId(), "DRIVER_ASSIGNED", rideId,
                rideViewMapper.toResponse(ride, ride.getPassenger().getId()));
        webSocketService.broadcastToAdmin("RIDE_ASSIGNED", Map.of("rideId", rideId, "driverId", driverId));
        log.info("Ride {} manually dispatched to driver {}{}", rideId, driverId,
                reTiered ? " after re-tiering" : "");
        return ride;
    }

    /** A driver declined: they stop being offered this ride, the round keeps running. */
    public void decline(Long driverId, Long rideId) {
        Round round = rounds.get(rideId);
        if (round == null) return;
        round.offeredDrivers.add(driverId);
        log.debug("Driver {} declined ride {}", driverId, rideId);
    }

    /** Drop a ride's offers entirely — passenger cancelled, or matching gave up. */
    public void closeRound(Long rideId, String reason) {
        Round round = rounds.remove(rideId);
        if (round == null) return;
        for (Long userId : round.offeredUserIds) {
            webSocketService.toDriver(userId, "OFFER_CANCELLED", rideId, Map.of("reason", reason));
        }
    }

    /**
     * Expire rounds once a second: widen the radius and re-offer, or give up and release
     * the ride with an explicit reason instead of leaving the passenger waiting.
     */
    @Scheduled(fixedDelay = 1000L)
    @Transactional
    public void sweepExpiredRounds() {
        if (rounds.isEmpty()) return;
        Instant now = Instant.now();
        List<Long> finished = new ArrayList<>();

        for (Round round : rounds.values()) {
            if (round.expiresAt != null && now.isBefore(round.expiresAt)) continue;
            if (finished.contains(round.rideId)) continue;

            Ride ride = rideRepository.findById(round.rideId).orElse(null);
            if (ride == null || ride.getStatus() != RideStatus.SEARCHING) {
                finished.add(round.rideId);
                continue;
            }

            double nextRadius = round.radiusKm * 2;
            if (round.radiusKm >= maxRadiusKm) {
                releaseWithNoDriver(ride);
                finished.add(round.rideId);
                continue;
            }

            round.radiusKm = Math.min(nextRadius, maxRadiusKm);
            round.roundNumber++;
            broadcastOffers(ride, round);
        }

        finished.forEach(id -> rounds.remove(id));
    }

    private void releaseWithNoDriver(Ride ride) {
        stateMachine.transition(ride, RideStatus.NO_DRIVER_FOUND, RideStateMachine.ACTOR_SYSTEM,
                "no driver accepted within " + maxRadiusKm + " km");
        rideRepository.save(ride);
        webSocketService.toPassenger(ride.getPassenger().getId(), "NO_DRIVER_FOUND", ride.getId(),
                Map.of("reason", "No drivers accepted within the search radius"));
        webSocketService.broadcastToAdmin("RIDE_NO_DRIVER", Map.of("rideId", ride.getId()));
        log.info("Ride {} released: no driver accepted", ride.getId());
    }

    /** Rebuild the live index after a restart, from the last known position of each driver. */
    @Transactional(readOnly = true)
    public int reindexFromDatabase() {
        List<Driver> matchable = driverRepository.findMatchable(DriverStatus.ONLINE);
        locationIndex.clear();
        presenceCache.clear();
        for (Driver d : matchable) {
            locationIndex.put(d.getId(), d.getUser().getId(), d.getCurrentLatitude(),
                    d.getCurrentLongitude(), d.getVehicleType());
            presenceCache.cache(d);
        }
        log.info("Rebuilt driver index with {} online drivers", matchable.size());
        return matchable.size();
    }

    /**
     * Offerability is a presence question, not an index one: a driver on a trip is still
     * placed so their rider can watch them move. An uncached driver is assumed free and
     * accept() re-reads the durable status before anyone is assigned.
     */
    private boolean isFreeForMatching(Long userId) {
        DriverPresenceCache.Ref ref = presenceCache.get(userId);
        return ref == null || ref.getStatus() == DriverStatus.ONLINE;
    }

    public int activeRounds() {
        return rounds.size();
    }
}
