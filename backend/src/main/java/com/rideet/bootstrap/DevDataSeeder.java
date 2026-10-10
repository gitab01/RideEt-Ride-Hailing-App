package com.rideet.bootstrap;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.entity.User;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.UserRole;
import com.rideet.domain.enums.VehicleType;
import com.rideet.repository.DriverRepository;
import com.rideet.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * Makes the dev database interesting: one passenger to request a ride and three verified,
 * online drivers parked around Bole so a request has somebody to match with the moment the
 * app starts. Never runs outside the dev profile.
 */
@Component
@Profile("dev")
@Order(2)
@RequiredArgsConstructor
@Slf4j
public class DevDataSeeder implements ApplicationRunner {

    /** Bole, Addis Ababa — the corner the demo drivers are parked around. */
    private static final double BASE_LAT = 8.9950;
    private static final double BASE_LNG = 38.7800;

    private final UserRepository userRepository;
    private final DriverRepository driverRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (userRepository.existsByEmail("passenger@rideet.com")) {
            return;
        }

        User passenger = userRepository.save(User.builder()
                .firstName("Abebe")
                .lastName("Kebede")
                .email("passenger@rideet.com")
                .phone("+251911000001")
                .password(passwordEncoder.encode("Passenger@1234"))
                .role(UserRole.PASSENGER)
                .build());

        Driver created = driverRepository.save(newDriver(
                userRepository.save(User.builder()
                        .firstName("Dawit")
                        .lastName("Tadesse")
                        .email("driver1@rideet.com")
                        .phone("+251911000011")
                        .password(passwordEncoder.encode("Driver@1234"))
                        .role(UserRole.DRIVER)
                        .build()),
                "Toyota", "Corolla", "2019", "AA-1234-B", "White", VehicleType.ECONOMY,
                BASE_LAT + 0.004, BASE_LNG + 0.003));

        driverRepository.save(newDriver(
                userRepository.save(User.builder()
                        .firstName("Mulugeta")
                        .lastName("Assefa")
                        .email("driver2@rideet.com")
                        .phone("+251911000012")
                        .password(passwordEncoder.encode("Driver@1234"))
                        .role(UserRole.DRIVER)
                        .build()),
                "Hyundai", "Sonata", "2021", "AA-5678-B", "Silver", VehicleType.STANDARD,
                BASE_LAT - 0.006, BASE_LNG + 0.008));

        driverRepository.save(newDriver(
                userRepository.save(User.builder()
                        .firstName("Yonas")
                        .lastName("Girma")
                        .email("driver3@rideet.com")
                        .phone("+251911000013")
                        .password(passwordEncoder.encode("Driver@1234"))
                        .role(UserRole.DRIVER)
                        .build()),
                "Toyota", "Vitz", "2018", "AA-9012-B", "Black", VehicleType.PREMIUM,
                BASE_LAT + 0.011, BASE_LNG - 0.009));

        log.info("Dev data ready: passenger {} and 3 online drivers (first id {})",
                passenger.getId(), created.getId());
    }

    private Driver newDriver(User user, String make, String model, String year, String plate,
                             String color, VehicleType type, double lat, double lng) {
        return Driver.builder()
                .user(user)
                .vehicleMake(make)
                .vehicleModel(model)
                .vehicleYear(year)
                .licensePlate(plate)
                .vehicleColor(color)
                .vehicleType(type)
                .documentsVerified(true)
                .status(DriverStatus.ONLINE)
                .currentLatitude(lat)
                .currentLongitude(lng)
                .lastLocationUpdate(LocalDateTime.now())
                .build();
    }
}
