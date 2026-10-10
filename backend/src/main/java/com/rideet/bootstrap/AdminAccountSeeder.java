package com.rideet.bootstrap;

import com.rideet.domain.entity.User;
import com.rideet.domain.enums.UserRole;
import com.rideet.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * The console is unreachable without an admin, and there is no self-service sign-up for
 * that role, so one account is guaranteed to exist. Runs in every profile and is a no-op
 * once the row is there.
 */
@Component
@Order(1)
@RequiredArgsConstructor
@Slf4j
public class AdminAccountSeeder implements ApplicationRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${admin.email:admin@rideet.com}")
    private String adminEmail;

    @Value("${admin.password:Admin@1234}")
    private String adminPassword;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (userRepository.existsByEmail(adminEmail)) {
            return;
        }
        userRepository.save(User.builder()
                .firstName("Super")
                .lastName("Admin")
                .email(adminEmail)
                .phone("+251000000000")
                .password(passwordEncoder.encode(adminPassword))
                .role(UserRole.ADMIN)
                .build());
        log.warn("Seeded admin account {} — change ADMIN_PASSWORD before any deployment that is reachable",
                adminEmail);
    }
}
