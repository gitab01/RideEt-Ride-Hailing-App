package com.rideet.websocket;

import com.rideet.dto.request.LocationUpdateRequest;
import com.rideet.service.DriverService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Controller;

import java.security.Principal;

@Controller
@RequiredArgsConstructor
@Slf4j
public class LocationWebSocketController {

    private final DriverService driverService;

    /**
     * Drivers stream their position here instead of polling REST.
     * Client sends to: /app/location.update
     *
     * <p>The principal is named by app-user id because {@link StompAuthChannelInterceptor}
     * authenticates the CONNECT frame and uses the id as the principal name.
     */
    @MessageMapping("/location.update")
    public void updateLocation(@Payload LocationUpdateRequest request, Principal principal) {
        if (principal == null) {
            log.warn("Dropping location update from an unauthenticated socket");
            return;
        }
        try {
            driverService.updateLocation(Long.valueOf(principal.getName()), request);
        } catch (NumberFormatException e) {
            log.warn("Socket principal '{}' is not a user id; ignoring location update", principal.getName());
        }
    }
}
