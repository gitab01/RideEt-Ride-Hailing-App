package com.rideet.controller;

import com.rideet.domain.enums.VehicleType;
import com.rideet.dto.request.DriverRejectionRequest;
import com.rideet.dto.request.VehicleTierUpdateRequest;
import com.rideet.dto.response.ApiResponse;
import com.rideet.dto.response.AdminDailyStatsResponse;
import com.rideet.dto.response.DriverResponse;
import com.rideet.dto.response.RideResponse;
import com.rideet.dto.response.UserResponse;
import com.rideet.dto.response.VehicleTierResponse;
import com.rideet.exception.ResourceNotFoundException;
import com.rideet.service.AdminService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/admin")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;

    @GetMapping("/dashboard")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getDashboard() {
        return ResponseEntity.ok(ApiResponse.success(adminService.getDashboardStats()));
    }

    @GetMapping("/users")
    public ResponseEntity<ApiResponse<Page<UserResponse>>> getUsers(@PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAllUsers(pageable)));
    }

    @GetMapping("/drivers")
    public ResponseEntity<ApiResponse<Page<DriverResponse>>> getDrivers(@PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAllDrivers(pageable)));
    }

    @PostMapping("/drivers/{driverId}/verify")
    public ResponseEntity<ApiResponse<DriverResponse>> verifyDriver(@PathVariable Long driverId) {
        return ResponseEntity.ok(ApiResponse.success("Driver verified",
                adminService.verifyDriverDocuments(driverId)));
    }

    @PostMapping("/drivers/{driverId}/reject")
    public ResponseEntity<ApiResponse<DriverResponse>> rejectDriver(
            @PathVariable Long driverId,
            @Valid @RequestBody DriverRejectionRequest request) {
        return ResponseEntity.ok(ApiResponse.success("Driver rejected",
                adminService.rejectDriverDocuments(driverId, request)));
    }

    /** Live map: every driver the matching engine can currently see. */
    @GetMapping("/drivers/locations")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getDriverLocations() {
        return ResponseEntity.ok(ApiResponse.success(adminService.getDriverLocations()));
    }

    /** Who could take this ride right now, with the fare each tier would charge for it. */
    @GetMapping("/rides/{rideId}/dispatch-candidates")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getDispatchCandidates(
            @PathVariable Long rideId) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getDispatchCandidates(rideId)));
    }

    @PostMapping("/rides/{rideId}/assign")
    public ResponseEntity<ApiResponse<RideResponse>> assignDriver(
            @PathVariable Long rideId,
            @RequestParam Long driverId) {
        return ResponseEntity.ok(ApiResponse.success("Driver dispatched",
                adminService.assignDriver(rideId, driverId)));
    }

    @PostMapping("/rides/{rideId}/cancel")
    public ResponseEntity<ApiResponse<RideResponse>> cancelRide(
            @PathVariable Long rideId,
            @RequestParam(defaultValue = "Cancelled from the admin console") String reason) {
        return ResponseEntity.ok(ApiResponse.success("Ride cancelled",
                adminService.cancelRide(rideId, reason)));
    }

    /** Requests and takings per day, for the dashboard trend charts. */
    @GetMapping("/stats/daily")
    public ResponseEntity<ApiResponse<AdminDailyStatsResponse>> getDailyStats(
            @RequestParam(defaultValue = "7") int days) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getDailyStats(days)));
    }

    @GetMapping("/pricing")
    public ResponseEntity<ApiResponse<List<VehicleTierResponse>>> getPricing() {
        return ResponseEntity.ok(ApiResponse.success(adminService.getPricing()));
    }

    @PutMapping("/pricing/{vehicleType}")
    public ResponseEntity<ApiResponse<VehicleTierResponse>> updatePricing(
            @PathVariable String vehicleType,
            @Valid @RequestBody VehicleTierUpdateRequest request) {
        return ResponseEntity.ok(ApiResponse.success("Pricing updated",
                adminService.updatePricing(tierOf(vehicleType), request)));
    }

    private VehicleType tierOf(String vehicleType) {
        try {
            return VehicleType.valueOf(vehicleType.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new ResourceNotFoundException("No such service tier: " + vehicleType);
        }
    }

    @PostMapping("/drivers/{driverId}/toggle-suspend")
    public ResponseEntity<ApiResponse<DriverResponse>> toggleDriverSuspension(@PathVariable Long driverId) {
        return ResponseEntity.ok(ApiResponse.success("Driver status updated",
                adminService.toggleDriverSuspension(driverId)));
    }

    @PostMapping("/users/{userId}/toggle-status")
    public ResponseEntity<ApiResponse<UserResponse>> toggleUserStatus(@PathVariable Long userId) {
        return ResponseEntity.ok(ApiResponse.success("User status updated",
                adminService.toggleUserStatus(userId)));
    }

    @GetMapping("/rides")
    public ResponseEntity<ApiResponse<Page<RideResponse>>> getAllRides(@PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAllRides(pageable)));
    }

    @GetMapping("/rides/active")
    public ResponseEntity<ApiResponse<List<RideResponse>>> getActiveRides() {
        return ResponseEntity.ok(ApiResponse.success(adminService.getActiveRides()));
    }

    @GetMapping("/rides/{rideId}/events")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getRideEvents(@PathVariable Long rideId) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getRideEvents(rideId)));
    }
}
