package com.rideet.controller;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.Ride;
import com.rideet.domain.entity.User;
import com.rideet.dto.response.ApiResponse;
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
    public ResponseEntity<ApiResponse<Page<User>>> getUsers(@PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAllPassengers(pageable)));
    }

    @GetMapping("/drivers")
    public ResponseEntity<ApiResponse<Page<Driver>>> getDrivers(@PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAllDrivers(pageable)));
    }

    @PostMapping("/drivers/{driverId}/verify")
    public ResponseEntity<ApiResponse<Driver>> verifyDriver(@PathVariable Long driverId) {
        Driver driver = adminService.verifyDriverDocuments(driverId);
        return ResponseEntity.ok(ApiResponse.success("Driver verified", driver));
    }

    @PostMapping("/drivers/{driverId}/toggle-suspend")
    public ResponseEntity<ApiResponse<Driver>> toggleDriverSuspension(@PathVariable Long driverId) {
        Driver driver = adminService.toggleDriverSuspension(driverId);
        return ResponseEntity.ok(ApiResponse.success("Driver status updated", driver));
    }

    @PostMapping("/users/{userId}/toggle-status")
    public ResponseEntity<ApiResponse<User>> toggleUserStatus(@PathVariable Long userId) {
        User user = adminService.toggleUserStatus(userId);
        return ResponseEntity.ok(ApiResponse.success("User status updated", user));
    }

    @GetMapping("/rides")
    public ResponseEntity<ApiResponse<Page<Ride>>> getAllRides(@PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAllRides(pageable)));
    }

    @GetMapping("/rides/active")
    public ResponseEntity<ApiResponse<List<Ride>>> getActiveRides() {
        return ResponseEntity.ok(ApiResponse.success(adminService.getActiveRides()));
    }
}
