package com.rideet.controller;

import com.rideet.domain.entity.User;
import com.rideet.dto.request.RatingRequest;
import com.rideet.dto.request.RideRequest;
import com.rideet.dto.response.ApiResponse;
import com.rideet.dto.response.FareEstimateResponse;
import com.rideet.dto.response.RideResponse;
import com.rideet.service.RideService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/rides")
@RequiredArgsConstructor
public class RideController {

    private final RideService rideService;

    @GetMapping("/estimate")
    public ResponseEntity<ApiResponse<FareEstimateResponse>> estimateFare(
            @RequestParam double pickupLat,
            @RequestParam double pickupLng,
            @RequestParam double destLat,
            @RequestParam double destLng) {

        FareEstimateResponse estimate = rideService.estimateFare(pickupLat, pickupLng, destLat, destLng);
        return ResponseEntity.ok(ApiResponse.success(estimate));
    }

    @PostMapping("/request")
    public ResponseEntity<ApiResponse<RideResponse>> requestRide(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody RideRequest request) {

        RideResponse ride = rideService.requestRide(user.getId(), request);
        return ResponseEntity.ok(ApiResponse.success("Ride requested", ride));
    }

    @GetMapping("/{rideId}")
    public ResponseEntity<ApiResponse<RideResponse>> getRide(@PathVariable Long rideId) {
        return ResponseEntity.ok(ApiResponse.success(rideService.getRideById(rideId)));
    }

    @PostMapping("/{rideId}/cancel")
    public ResponseEntity<ApiResponse<RideResponse>> cancelRide(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId,
            @RequestParam(required = false) String reason) {

        RideResponse ride = rideService.cancelRide(user.getId(), rideId, reason, "PASSENGER");
        return ResponseEntity.ok(ApiResponse.success("Ride cancelled", ride));
    }

    @PostMapping("/{rideId}/rate")
    public ResponseEntity<ApiResponse<Void>> rateDriver(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId,
            @Valid @RequestBody RatingRequest request) {

        rideService.rateDriver(user.getId(), rideId, request);
        return ResponseEntity.ok(ApiResponse.success("Rating submitted", null));
    }

    @GetMapping("/history")
    public ResponseEntity<ApiResponse<Page<RideResponse>>> getHistory(
            @AuthenticationPrincipal User user,
            @PageableDefault(size = 10) Pageable pageable) {

        return ResponseEntity.ok(ApiResponse.success(
                rideService.getPassengerHistory(user.getId(), pageable)));
    }
}
