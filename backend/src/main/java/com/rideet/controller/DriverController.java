package com.rideet.controller;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.User;
import com.rideet.dto.request.DriverRegisterRequest;
import com.rideet.dto.request.LocationUpdateRequest;
import com.rideet.dto.request.RatingRequest;
import com.rideet.dto.response.ApiResponse;
import com.rideet.dto.response.DriverResponse;
import com.rideet.dto.response.RideResponse;
import com.rideet.matching.RideStateMachine;
import com.rideet.service.DriverService;
import com.rideet.service.RideService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/driver")
@RequiredArgsConstructor
@PreAuthorize("hasRole('DRIVER')")
public class DriverController {

    private final DriverService driverService;
    private final RideService rideService;

    /** Onboarding: turn a DRIVER account into a matchable driver with a vehicle. */
    @PostMapping("/register")
    public ResponseEntity<ApiResponse<DriverResponse>> register(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody DriverRegisterRequest request) {

        return ResponseEntity.ok(ApiResponse.success("Driver profile created",
                driverService.register(user.getId(), request)));
    }

    @PostMapping("/documents")
    public ResponseEntity<ApiResponse<DriverResponse>> submitDocuments(
            @AuthenticationPrincipal User user,
            @RequestParam String driverLicenseUrl,
            @RequestParam String vehicleRegistrationUrl,
            @RequestParam(required = false) String insuranceUrl) {

        return ResponseEntity.ok(ApiResponse.success("Documents submitted",
                driverService.submitDocuments(user.getId(), driverLicenseUrl,
                        vehicleRegistrationUrl, insuranceUrl)));
    }

    @GetMapping("/profile")
    public ResponseEntity<ApiResponse<DriverResponse>> getProfile(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(ApiResponse.success(driverService.getProfile(user.getId())));
    }

    @PostMapping("/online")
    public ResponseEntity<ApiResponse<DriverResponse>> goOnline(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(ApiResponse.success("Now online", driverService.goOnline(user.getId())));
    }

    @PostMapping("/offline")
    public ResponseEntity<ApiResponse<DriverResponse>> goOffline(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(ApiResponse.success("Now offline", driverService.goOffline(user.getId())));
    }

    /** REST fallback for location; the socket path is preferred while the app is connected. */
    @PostMapping("/location")
    public ResponseEntity<ApiResponse<Void>> updateLocation(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody LocationUpdateRequest request) {

        driverService.updateLocation(user.getId(), request);
        return ResponseEntity.ok(ApiResponse.success("Location updated", null));
    }

    @PostMapping("/rides/{rideId}/accept")
    public ResponseEntity<ApiResponse<RideResponse>> acceptRide(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        return ResponseEntity.ok(ApiResponse.success("Ride accepted",
                rideService.acceptRide(driver.getId(), rideId)));
    }

    @PostMapping("/rides/{rideId}/decline")
    public ResponseEntity<ApiResponse<Void>> declineRide(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        rideService.declineOffer(driver.getId(), rideId);
        return ResponseEntity.ok(ApiResponse.success("Offer declined", null));
    }

    @PostMapping("/rides/{rideId}/arrived")
    public ResponseEntity<ApiResponse<RideResponse>> markArrived(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        return ResponseEntity.ok(ApiResponse.success("Arrival confirmed",
                rideService.markDriverArrived(driver.getId(), rideId, user.getId())));
    }

    @PostMapping("/rides/{rideId}/start")
    public ResponseEntity<ApiResponse<RideResponse>> startRide(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId,
            @RequestParam String otp) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        return ResponseEntity.ok(ApiResponse.success("Ride started",
                rideService.startRide(driver.getId(), rideId, otp)));
    }

    @PostMapping("/rides/{rideId}/complete")
    public ResponseEntity<ApiResponse<RideResponse>> completeRide(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        return ResponseEntity.ok(ApiResponse.success("Ride completed",
                rideService.completeRide(driver.getId(), rideId)));
    }

    @PostMapping("/rides/{rideId}/cancel")
    public ResponseEntity<ApiResponse<RideResponse>> cancelRide(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId,
            @RequestParam(required = false) String reason) {

        // cancelRide authorises by app-user id, so the driver's own id is what proves
        // they are the assigned party — not their driver row id.
        return ResponseEntity.ok(ApiResponse.success("Ride cancelled",
                rideService.cancelRide(user.getId(), rideId, reason, RideStateMachine.ACTOR_DRIVER)));
    }

    @PostMapping("/rides/{rideId}/rate")
    public ResponseEntity<ApiResponse<Void>> ratePassenger(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId,
            @Valid @RequestBody RatingRequest request) {

        rideService.rateRide(user.getId(), rideId, request);
        return ResponseEntity.ok(ApiResponse.success("Rating submitted", null));
    }

    @GetMapping("/rides/active")
    public ResponseEntity<ApiResponse<List<RideResponse>>> getActiveRides(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(ApiResponse.success(rideService.getActiveRideForUser(user.getId())));
    }

    @GetMapping("/rides/{rideId}")
    public ResponseEntity<ApiResponse<RideResponse>> getRide(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId) {

        return ResponseEntity.ok(ApiResponse.success(rideService.getRideForUser(user.getId(), rideId)));
    }

    @GetMapping("/rides/history")
    public ResponseEntity<ApiResponse<Page<RideResponse>>> getHistory(
            @AuthenticationPrincipal User user,
            @PageableDefault(size = 10) Pageable pageable) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        return ResponseEntity.ok(ApiResponse.success(
                rideService.getDriverHistory(driver.getId(), pageable)));
    }
}
