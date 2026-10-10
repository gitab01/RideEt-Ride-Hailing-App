package com.rideet.matching;

import com.rideet.domain.entity.Driver;
import com.rideet.domain.enums.DriverStatus;
import com.rideet.domain.enums.VehicleType;
import lombok.Getter;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Identity and availability of each driver, keyed by their app-user id.
 *
 * <p>Location pings arrive every few seconds from every online driver. Resolving
 * user id -> driver through the database on each one would put a SELECT on the hot
 * path, so the pair is cached here and refreshed when a driver's status actually changes.
 */
@Component
public class DriverPresenceCache {

    @Getter
    public static final class Ref {
        private final Long driverId;
        private final Long userId;
        private final VehicleType vehicleType;
        private volatile DriverStatus status;

        Ref(Long driverId, Long userId, VehicleType vehicleType, DriverStatus status) {
            this.driverId = driverId;
            this.userId = userId;
            this.vehicleType = vehicleType;
            this.status = status;
        }
    }

    private final Map<Long, Ref> byUserId = new ConcurrentHashMap<>();

    public Ref cache(Driver driver) {
        Ref ref = new Ref(driver.getId(), driver.getUser().getId(),
                driver.getVehicleType(), driver.getStatus());
        byUserId.put(ref.userId, ref);
        return ref;
    }

    public Ref get(Long userId) {
        return byUserId.get(userId);
    }

    public void evict(Long userId) {
        byUserId.remove(userId);
    }

    public void evictDriver(Long driverId) {
        byUserId.values().removeIf(r -> r.driverId.equals(driverId));
    }

    /** Reflect a status change made elsewhere without re-reading the row. */
    public void statusChanged(Long userId, DriverStatus status) {
        Ref ref = byUserId.get(userId);
        if (ref != null) ref.status = status;
    }

    public void clear() {
        byUserId.clear();
    }

    public int size() {
        return byUserId.size();
    }
}
