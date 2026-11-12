package com.rideet.matching;

import com.rideet.domain.enums.RideStatus;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The transition table is the only thing standing between a late driver tap and a ride that is
 * already finished, so the edges are asserted one by one rather than through an endpoint.
 */
class RideStateMachineTest {

    @Test
    void aNewRideMayOnlyStartSearchingOrBeCancelled() {
        assertTrue(RideStateMachine.canTransition(null, RideStatus.REQUESTED));
        assertFalse(RideStateMachine.canTransition(null, RideStatus.DRIVER_ASSIGNED));

        assertTrue(RideStateMachine.canTransition(RideStatus.REQUESTED, RideStatus.SEARCHING));
        assertTrue(RideStateMachine.canTransition(RideStatus.REQUESTED, RideStatus.CANCELLED));
        assertFalse(RideStateMachine.canTransition(RideStatus.REQUESTED, RideStatus.IN_PROGRESS));
    }

    @Test
    void aFailedSearchIsTerminalSoNoDriverCanClaimItLater() {
        assertTrue(RideStateMachine.canTransition(RideStatus.SEARCHING, RideStatus.NO_DRIVER_FOUND));
        assertFalse(RideStateMachine.canTransition(RideStatus.NO_DRIVER_FOUND, RideStatus.DRIVER_ASSIGNED));
        assertTrue(RideStateMachine.allowedFrom(RideStatus.NO_DRIVER_FOUND).isEmpty());
    }

    @Test
    void aDriverBackOutOfAnAssignmentButNobodyExtendsATrip() {
        assertTrue(RideStateMachine.canTransition(RideStatus.DRIVER_ASSIGNED, RideStatus.SEARCHING));
        assertTrue(RideStateMachine.canTransition(RideStatus.DRIVER_ARRIVED, RideStatus.IN_PROGRESS));

        assertFalse(RideStateMachine.canTransition(RideStatus.IN_PROGRESS, RideStatus.CANCELLED));
        assertFalse(RideStateMachine.canTransition(RideStatus.IN_PROGRESS, RideStatus.DRIVER_ASSIGNED));
        assertTrue(RideStateMachine.canTransition(RideStatus.IN_PROGRESS, RideStatus.COMPLETED));
    }

    @Test
    void noRouteLeavesAFinishedRide() {
        for (RideStatus target : RideStatus.values()) {
            assertFalse(RideStateMachine.canTransition(RideStatus.COMPLETED, target),
                    "COMPLETED must not move to " + target);
            assertFalse(RideStateMachine.canTransition(RideStatus.CANCELLED, target),
                    "CANCELLED must not move to " + target);
        }
    }
}
