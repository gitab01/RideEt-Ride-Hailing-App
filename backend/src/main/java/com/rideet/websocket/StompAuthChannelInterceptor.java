package com.rideet.websocket;

import com.rideet.domain.entity.User;
import com.rideet.repository.UserRepository;
import com.rideet.security.JwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.stereotype.Component;

/**
 * Gives a STOMP session an authenticated principal.
 *
 * <p>Without this nothing is ever delivered to {@code /user/queue/...} and the location
 * upload handler cannot tell which driver it is talking to. The token arrives as a STOMP
 * {@code Authorization} header on CONNECT, which both the raw WebSocket clients and the
 * browser SockJS client can set.
 *
 * <p>The principal is named by <em>app user id</em>, not email, so pushes addressed to a
 * user id actually land in that user's queue.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class StompAuthChannelInterceptor implements ChannelInterceptor {

    private static final String BEARER = "Bearer ";

    private final JwtService jwtService;
    private final UserRepository userRepository;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null) return message;

        if (StompCommand.CONNECT.equals(accessor.getCommand())) {
            String token = bearerToken(accessor.getFirstNativeHeader("Authorization"));
            if (token == null) {
                token = accessor.getFirstNativeHeader("X-Access-Token");
            }
            if (token == null) {
                throw new IllegalArgumentException("Missing STOMP credentials");
            }
            User user = authenticate(token);
            if (user == null) {
                throw new IllegalArgumentException("Invalid STOMP credentials");
            }
            accessor.setUser(new UsernamePasswordAuthenticationToken(
                    user.getId().toString(), null, user.getAuthorities()));
            log.debug("STOMP session opened by user id {}", user.getId());
        }
        return message;
    }

    private String bearerToken(String header) {
        if (header == null) return null;
        return header.startsWith(BEARER) ? header.substring(BEARER.length()).trim() : header.trim();
    }

    private User authenticate(String token) {
        try {
            String email = jwtService.extractUsername(token);
            return userRepository.findByEmail(email).orElse(null);
        } catch (Exception e) {
            log.debug("Rejected STOMP token: {}", e.getMessage());
            return null;
        }
    }
}
