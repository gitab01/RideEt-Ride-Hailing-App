package com.rideet.websocket;

import com.rideet.dto.request.LocationUpdateRequest;
import com.rideet.service.DriverService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Controller;

import java.security.Principal;

@Controller
@RequiredArgsConstructor
public class LocationWebSocketController {

    private final DriverService driverService;

    /**
     * Drivers send location updates via WebSocket.
     * Client sends to: /app/location.update
     */
    @MessageMapping("/location.update")
    public void updateLocation(@Payload LocationUpdateRequest request, Principal principal) {
        if (principal != null) {
            // Extract userId from principal name (email)
            // Resolve user -> driver and update
            try {
                Long userId = Long.parseLong(principal.getName());
                driverService.updateLocation(userId, request);
            } catch (NumberFormatException ignored) {
                // principal may be email; handle accordingly
            }
        }
    }
}
