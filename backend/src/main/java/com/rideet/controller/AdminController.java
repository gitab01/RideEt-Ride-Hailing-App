package com.rideet.controller;

import com.rideet.dto.response.ApiResponse;
import com.rideet.dto.response.DriverResponse;
import com.rideet.dto.response.RideResponse;
import com.rideet.dto.response.UserResponse;
import com.rideet.service.AdminService;
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
