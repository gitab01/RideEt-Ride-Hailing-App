package com.rideet.domain.enums;

public enum RideStatus {
    REQUESTED,       // Passenger requested a ride
    SEARCHING,       // Looking for nearby drivers
    DRIVER_ASSIGNED, // Driver accepted and heading to pickup
    DRIVER_ARRIVED,  // Driver is at pickup location
    IN_PROGRESS,     // Ride is ongoing
    COMPLETED,       // Ride finished
    CANCELLED,       // Ride cancelled by passenger or driver
    NO_DRIVER_FOUND  // No driver available
}
