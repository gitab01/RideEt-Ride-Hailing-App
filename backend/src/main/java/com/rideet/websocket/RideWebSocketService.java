package com.rideet.websocket;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class RideWebSocketService {

    private final SimpMessagingTemplate messagingTemplate;

    /**
     * Notify a specific passenger about ride status changes.
     */
    public void notifyPassenger(Long passengerId, String eventType, Long rideId) {
        Map<String, Object> payload = Map.of(
                "eventType", eventType,
                "rideId", rideId
        );
        messagingTemplate.convertAndSendToUser(
                passengerId.toString(),
                "/queue/ride-updates",
                payload
        );
        log.debug("Notified passenger {} with event: {}", passengerId, eventType);
    }

    /**
     * Notify a specific driver about a new ride request.
     */
    public void notifyDriver(Long driverId, String eventType, Long rideId) {
        Map<String, Object> payload = Map.of(
                "eventType", eventType,
                "rideId", rideId
        );
        messagingTemplate.convertAndSendToUser(
                driverId.toString(),
                "/queue/ride-requests",
                payload
        );
        log.debug("Notified driver {} with event: {}", driverId, eventType);
    }

    /**
     * Broadcast driver location to passengers tracking that driver.
     */
    public void broadcastDriverLocation(Long driverId, double lat, double lng,
                                         Double heading, Double speed) {
        Map<String, Object> payload = Map.of(
                "driverId", driverId,
                "latitude", lat,
                "longitude", lng,
                "heading", heading != null ? heading : 0.0,
                "speed", speed != null ? speed : 0.0
        );
        messagingTemplate.convertAndSend(
                "/topic/driver-location/" + driverId,
                payload
        );
    }

    /**
     * Broadcast to admin dashboard - active ride updates.
     */
    public void broadcastToAdmin(String eventType, Object data) {
        Map<String, Object> payload = Map.of(
                "eventType", eventType,
                "data", data
        );
        messagingTemplate.convertAndSend("/topic/admin/live-rides", payload);
    }
}
