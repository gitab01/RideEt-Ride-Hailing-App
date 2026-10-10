package com.rideet.mapper;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.Ride;
import com.rideet.domain.entity.User;
import com.rideet.domain.enums.RideStatus;
import com.rideet.dto.response.RideResponse;
import org.springframework.stereotype.Component;

/**
 * Entity to wire-format. Lives apart from the services because both the ride lifecycle and
 * the matching engine need to push a ride to a client, and letting one depend on the other
 * would close a cycle.
 *
 * <p>Must be called inside a transaction: {@code passenger} and {@code driver.user} are lazy
 * associations and {@code open-in-view} is off.
 */
@Component
public class RideViewMapper {

    /**
     * @param viewerUserId the requesting user. The start code only ever goes to the passenger,
     *                     since a driver who could read it would not need to ask for it.
     */
    public RideResponse toResponse(Ride ride, Long viewerUserId) {
        User passenger = ride.getPassenger();
        RideResponse.RideResponseBuilder builder = RideResponse.builder()
                .id(ride.getId())
                .passengerId(passenger.getId())
                .passengerName(passenger.getFullName())
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
                .surgeMultiplier(ride.getSurgeMultiplier())
                .paymentMethod(ride.getPaymentMethod())
                .requestedAt(ride.getRequestedAt())
                .driverAssignedAt(ride.getDriverAssignedAt())
                .startedAt(ride.getStartedAt())
                .completedAt(ride.getCompletedAt())
                .cancelledAt(ride.getCancelledAt())
                .ratingByPassenger(ride.getPassengerRating())
                .reviewByPassenger(ride.getPassengerReview())
                .ratingByDriver(ride.getDriverRating())
                .reviewByDriver(ride.getDriverReview())
                .cancelledBy(ride.getCancelledBy())
                .cancellationReason(ride.getCancellationReason());

        // The code matters only between assignment and boarding; repeating it in every
        // history row would put a dead credential in list payloads.
        boolean awaitingBoarding = ride.getStatus() == RideStatus.DRIVER_ASSIGNED
                || ride.getStatus() == RideStatus.DRIVER_ARRIVED;
        if (awaitingBoarding && viewerUserId != null && viewerUserId.equals(passenger.getId())) {
            builder.rideStartOtp(ride.getRideStartOtp());
        }

        if (ride.getDriver() != null) {
            Driver driver = ride.getDriver();
            User driverUser = driver.getUser();
            builder.driverId(driver.getId())
                    .driverUserId(driverUser == null ? null : driverUser.getId())
                    .driverName(driverUser == null ? null : driverUser.getFullName())
                    .driverPhone(driverUser == null ? null : driverUser.getPhone())
                    .driverProfilePicture(driverUser == null ? null : driverUser.getProfilePictureUrl())
                    .driverRating(driver.getRating())
                    .vehicleMake(driver.getVehicleMake())
                    .vehicleModel(driver.getVehicleModel())
                    .licensePlate(driver.getLicensePlate())
                    .vehicleColor(driver.getVehicleColor());
        }

        return builder.build();
    }
}
