package com.rideet.matching;

import com.rideet.domain.entity.Ride;
import com.rideet.domain.entity.RideEvent;
import com.rideet.domain.enums.RideStatus;
import com.rideet.exception.BadRequestException;
import com.rideet.repository.RideEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collections;
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.Map;
import java.util.Set;

/**
 * The only place a ride's status may change.
 *
 * <p>Clients request transitions; this validates the pair against the allowed graph,
 * applies it and appends the history row. A client that claims "trip started" out of
 * order is rejected rather than trusted, which is what keeps a fare from being
 * inflated or deflated from the phone.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class RideStateMachine {

    public static final String ACTOR_PASSENGER = "PASSENGER";
    public static final String ACTOR_DRIVER = "DRIVER";
    public static final String ACTOR_SYSTEM = "SYSTEM";

    private static final Map<RideStatus, Set<RideStatus>> ALLOWED = new EnumMap<>(RideStatus.class);

    static {
        ALLOWED.put(RideStatus.REQUESTED, EnumSet.of(RideStatus.SEARCHING, RideStatus.CANCELLED));
        ALLOWED.put(RideStatus.SEARCHING, EnumSet.of(
                RideStatus.DRIVER_ASSIGNED, RideStatus.NO_DRIVER_FOUND, RideStatus.CANCELLED));
        ALLOWED.put(RideStatus.DRIVER_ASSIGNED, EnumSet.of(
                RideStatus.DRIVER_ARRIVED, RideStatus.SEARCHING, RideStatus.CANCELLED));
        ALLOWED.put(RideStatus.DRIVER_ARRIVED, EnumSet.of(
                RideStatus.IN_PROGRESS, RideStatus.SEARCHING, RideStatus.CANCELLED));
        ALLOWED.put(RideStatus.IN_PROGRESS, EnumSet.of(RideStatus.COMPLETED));
        ALLOWED.put(RideStatus.COMPLETED, EnumSet.noneOf(RideStatus.class));
        ALLOWED.put(RideStatus.CANCELLED, EnumSet.noneOf(RideStatus.class));
        ALLOWED.put(RideStatus.NO_DRIVER_FOUND, EnumSet.noneOf(RideStatus.class));
    }

    private final RideEventRepository rideEventRepository;

    public static boolean canTransition(RideStatus from, RideStatus to) {
        if (from == null) return to == RideStatus.REQUESTED;
        return ALLOWED.getOrDefault(from, EnumSet.noneOf(RideStatus.class)).contains(to);
    }

    public static Set<RideStatus> allowedFrom(RideStatus from) {
        return Collections.unmodifiableSet(ALLOWED.getOrDefault(from, EnumSet.noneOf(RideStatus.class)));
    }

    /**
     * @return the appended history row
     * @throws BadRequestException if the transition is not legal from the current state
     */
    @Transactional
    public RideEvent transition(Ride ride, RideStatus to, String actor, String note) {
        RideStatus from = ride.getStatus();
        if (!canTransition(from, to)) {
            throw new BadRequestException(
                    "Illegal ride transition " + from + " -> " + to + " for ride " + ride.getId());
        }
        ride.setStatus(to);
        return recordTransition(ride, from, to, actor, note);
    }

    /**
     * Append history for a transition whose legality was already settled by something
     * other than this method — namely the status compare-and-set that decides which
     * driver won an offer.
     */
    @Transactional
    public RideEvent recordTransition(Ride ride, RideStatus from, RideStatus to, String actor, String note) {
        RideEvent event = rideEventRepository.save(RideEvent.builder()
                .ride(ride)
                .fromStatus(from)
                .toStatus(to)
                .actor(actor)
                .note(note)
                .build());
        log.debug("Ride {} {} -> {} by {}", ride.getId(), from, to, actor);
        return event;
    }
}
