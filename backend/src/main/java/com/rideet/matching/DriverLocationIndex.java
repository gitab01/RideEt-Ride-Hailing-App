package com.rideet.matching;

import com.rideet.common.GeoUtil;
import com.rideet.domain.enums.VehicleType;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory geospatial index of live driver positions.
 *
 * <p>Drivers are bucketed into fixed-size cells. A lookup scans the cell containing the
 * pickup and then whole rings of cells outward until {@code radiusKm} is covered, which
 * keeps a ride request off the database entirely — the durable {@code driver_locations}
 * trail is written separately, in batches.
 */
@Component
@Slf4j
public class DriverLocationIndex {

    public record Placement(Long driverId, Long userId, double latitude, double longitude,
                            VehicleType vehicleType, long updatedAtMillis) {
    }

    /** A driver id plus the distance to it, in ascending order. */
    public record Candidate(Long driverId, Long userId, double distanceKm) {
    }

    private record CellKey(int x, int y) {
    }

    private final Map<Long, Placement> placements = new ConcurrentHashMap<>();
    private final Map<CellKey, Map<Long, Placement>> cells = new ConcurrentHashMap<>();
    private final double cellDeg;

    public DriverLocationIndex(@Value("${matching.cell-size-km:2.0}") double cellSizeKm) {
        this.cellDeg = GeoUtil.degreesFor(Math.max(0.1, cellSizeKm));
    }

    public void put(Long driverId, Long userId, double lat, double lng, VehicleType vehicleType) {
        Placement next = new Placement(driverId, userId, lat, lng, vehicleType, System.currentTimeMillis());
        Placement previous = placements.put(driverId, next);
        if (previous != null) {
            Map<Long, Placement> oldCell = cells.get(cellOf(previous.latitude(), previous.longitude()));
            if (oldCell != null) {
                oldCell.remove(driverId);
                if (oldCell.isEmpty()) cells.remove(cellOf(previous.latitude(), previous.longitude()));
            }
        }
        cells.computeIfAbsent(cellOf(lat, lng), k -> new ConcurrentHashMap<>()).put(driverId, next);
    }

    public void remove(Long driverId) {
        Placement previous = placements.remove(driverId);
        if (previous == null) return;
        CellKey key = cellOf(previous.latitude(), previous.longitude());
        Map<Long, Placement> cell = cells.get(key);
        if (cell != null) {
            cell.remove(driverId);
            if (cell.isEmpty()) cells.remove(key);
        }
    }

    public boolean contains(Long driverId) {
        return placements.containsKey(driverId);
    }

    public java.util.Optional<Placement> placementOf(Long driverId) {
        return java.util.Optional.ofNullable(placements.get(driverId));
    }

    public int size() {
        return placements.size();
    }

    /**
     * Nearest-first search. Results exclude {@code exclude} (drivers already offered this
     * ride) and are capped at {@code limit}.
     */
    public List<Candidate> nearest(double lat, double lng, double radiusKm,
                                   VehicleType vehicleType, Set<Long> exclude, int limit) {
        CellKey centre = cellOf(lat, lng);
        int rings = (int) Math.ceil(radiusKm / (cellDeg * GeoUtil.KM_PER_DEGREE)) + 1;

        List<Candidate> found = new ArrayList<>();
        Set<Long> seenDrivers = new HashSet<>();
        for (int dx = -rings; dx <= rings; dx++) {
            for (int dy = -rings; dy <= rings; dy++) {
                Map<Long, Placement> cell = cells.get(new CellKey(centre.x() + dx, centre.y() + dy));
                if (cell == null) continue;
                for (Placement p : cell.values()) {
                    if (!seenDrivers.add(p.driverId())) continue;
                    if (exclude != null && exclude.contains(p.driverId())) continue;
                    if (vehicleType != null && p.vehicleType() != vehicleType) continue;
                    double distance = GeoUtil.kmBetween(lat, lng, p.latitude(), p.longitude());
                    if (distance <= radiusKm) {
                        found.add(new Candidate(p.driverId(), p.userId(), distance));
                    }
                }
            }
        }
        found.sort(Comparator.comparingDouble(Candidate::distanceKm));
        return limit > 0 && found.size() > limit ? new ArrayList<>(found.subList(0, limit)) : found;
    }

    /** Positions currently held, for the startup rebuild and the admin live map. */
    public List<Placement> snapshot() {
        return new ArrayList<>(placements.values());
    }

    public void clear() {
        placements.clear();
        cells.clear();
    }

    private CellKey cellOf(double lat, double lng) {
        return new CellKey((int) Math.floor(lat / cellDeg), (int) Math.floor(lng / cellDeg));
    }

    @Override
    public String toString() {
        return "DriverLocationIndex{drivers=" + placements.size() + ", cells=" + cells.size() + "}";
    }
}
