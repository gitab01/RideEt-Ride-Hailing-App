package com.rideet.service;

import com.rideet.domain.entity.Notification;
import com.rideet.domain.entity.User;
import com.rideet.exception.ResourceNotFoundException;
import com.rideet.repository.NotificationRepository;
import com.rideet.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;

    @Async
    public void sendPushNotification(Long userId, String title, String message) {
        // Save in-app notification
        User user = userRepository.findById(userId).orElse(null);
        if (user == null) return;

        Notification notification = Notification.builder()
                .user(user)
                .title(title)
                .message(message)
                .type("GENERAL")
                .build();
        notificationRepository.save(notification);

        // TODO: Integrate FCM for real push notifications
        // String fcmToken = user.getFcmToken();
        // if (fcmToken != null) { firebaseService.sendNotification(fcmToken, title, message); }
        log.info("Notification sent to user {}: {}", userId, title);
    }

    public Page<Notification> getUserNotifications(Long userId, Pageable pageable) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
    }

    public long getUnreadCount(Long userId) {
        return notificationRepository.countByUserIdAndReadFalse(userId);
    }

    @Transactional
    public void markAllRead(Long userId) {
        notificationRepository.markAllReadForUser(userId);
    }
}
