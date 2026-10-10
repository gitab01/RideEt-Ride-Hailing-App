package com.rideet.websocket;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Outbound realtime pushes.
 *
 * <p>Everything addressed to one person uses that person's app-user id, because the
 * STOMP principal installed by {@link StompAuthChannelInterceptor} is named by user id.
 * Clients subscribe to {@code /user/queue/...} and Spring routes by principal.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RideWebSocketService {

    public static final String PASSENGER_QUEUE = "/queue/ride-updates";
    public static final String DRIVER_QUEUE = "/queue/ride-requests";
    public static final String DRIVER_LOCATION_TOPIC = "/topic/driver-location/";
    public static final String ADMIN_TOPIC = "/topic/admin/live-rides";

    private final SimpMessagingTemplate messagingTemplate;

    public void toPassenger(Long userId, String eventType, Long rideId, Object data) {
        send(userId, PASSENGER_QUEUE, eventType, rideId, data);
    }

    public void toDriver(Long userId, String eventType, Long rideId, Object data) {
        send(userId, DRIVER_QUEUE, eventType, rideId, data);
    }

    private void send(Long userId, String queue, String eventType, Long rideId, Object data) {
        if (userId == null) return;
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("eventType", eventType);
        payload.put("rideId", rideId);
        payload.put("data", data);
        messagingTemplate.convertAndSendToUser(userId.toString(), queue, payload);
        log.debug("Pushed {} to user {} on {}", eventType, userId, queue);
    }

    /** Interpolated driver motion for whoever is tracking this driver. */
    public void broadcastDriverLocation(Long driverUserId, double lat, double lng,
                                        Double heading, Double speedKmh, Long rideId) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("driverUserId", driverUserId);
        payload.put("rideId", rideId);
        payload.put("latitude", lat);
        payload.put("longitude", lng);
        payload.put("heading", heading == null ? 0.0 : heading);
        payload.put("speedKmh", speedKmh == null ? 0.0 : speedKmh);
        payload.put("timestamp", System.currentTimeMillis());
        messagingTemplate.convertAndSend(DRIVER_LOCATION_TOPIC + driverUserId, payload);
    }

    /** Admin live map feed. */
    public void broadcastToAdmin(String eventType, Object data) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("eventType", eventType);
        payload.put("data", data);
        messagingTemplate.convertAndSend(ADMIN_TOPIC, payload);
    }
}
