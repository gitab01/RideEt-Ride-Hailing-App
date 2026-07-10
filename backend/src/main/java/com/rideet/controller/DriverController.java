package com.rideet.controller;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.User;
import com.rideet.dto.request.LocationUpdateRequest;
import com.rideet.dto.request.RatingRequest;
import com.rideet.dto.response.ApiResponse;
import com.rideet.dto.response.RideResponse;
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

@RestController
@RequestMapping("/driver")
@RequiredArgsConstructor
public class DriverController {

    private final DriverService driverService;
    private final RideService rideService;

    @PostMapping("/online")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<Driver>> goOnline(@AuthenticationPrincipal User user) {
        Driver driver = driverService.goOnline(user.getId());
        return ResponseEntity.ok(ApiResponse.success("Now online", driver));
    }

    @PostMapping("/offline")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<Driver>> goOffline(@AuthenticationPrincipal User user) {
        Driver driver = driverService.goOffline(user.getId());
        return ResponseEntity.ok(ApiResponse.success("Now offline", driver));
    }

    @PostMapping("/location")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<Void>> updateLocation(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody LocationUpdateRequest request) {

        driverService.updateLocation(user.getId(), request);
        return ResponseEntity.ok(ApiResponse.success("Location updated", null));
    }

    @PostMapping("/rides/{rideId}/accept")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<RideResponse>> acceptRide(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        RideResponse ride = rideService.acceptRide(driver.getId(), rideId);
        return ResponseEntity.ok(ApiResponse.success("Ride accepted", ride));
    }

    @PostMapping("/rides/{rideId}/arrived")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<RideResponse>> markArrived(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        RideResponse ride = rideService.markDriverArrived(driver.getId(), rideId);
        return ResponseEntity.ok(ApiResponse.success("Arrival confirmed", ride));
    }

    @PostMapping("/rides/{rideId}/start")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<RideResponse>> startRide(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId,
            @RequestParam String otp) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        RideResponse ride = rideService.startRide(driver.getId(), rideId, otp);
        return ResponseEntity.ok(ApiResponse.success("Ride started", ride));
    }

    @PostMapping("/rides/{rideId}/complete")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<RideResponse>> completeRide(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        RideResponse ride = rideService.completeRide(driver.getId(), rideId);
        return ResponseEntity.ok(ApiResponse.success("Ride completed", ride));
    }

    @PostMapping("/rides/{rideId}/cancel")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<RideResponse>> cancelRide(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId,
            @RequestParam(required = false) String reason) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        RideResponse ride = rideService.cancelRide(driver.getId(), rideId, reason, "DRIVER");
        return ResponseEntity.ok(ApiResponse.success("Ride cancelled", ride));
    }

    @GetMapping("/rides/history")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<Page<RideResponse>>> getHistory(
            @AuthenticationPrincipal User user,
            @PageableDefault(size = 10) Pageable pageable) {

        Driver driver = driverService.getDriverByUserId(user.getId());
        return ResponseEntity.ok(ApiResponse.success(
                rideService.getDriverHistory(driver.getId(), pageable)));
    }

    @GetMapping("/profile")
    @PreAuthorize("hasRole('DRIVER')")
    public ResponseEntity<ApiResponse<Driver>> getProfile(@AuthenticationPrincipal User user) {
        Driver driver = driverService.getDriverByUserId(user.getId());
        return ResponseEntity.ok(ApiResponse.success(driver));
    }
}
