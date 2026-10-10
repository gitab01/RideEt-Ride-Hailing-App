package com.rideet.matching;

import com.rideet.domain.entity.DriverLocation;
import com.rideet.repository.DriverLocationRepository;
import com.rideet.repository.DriverRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Buffers driver pings and writes them in batches.
 *
 * <p>One insert per ping from every online driver would dominate database load, so the
 * live position goes straight into {@link DriverLocationIndex} and the durable trail is
 * flushed on a timer.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class LocationWriteBuffer {

    private final DriverLocationRepository driverLocationRepository;
    private final DriverRepository driverRepository;

    private final ConcurrentLinkedQueue<DriverLocation> pending = new ConcurrentLinkedQueue<>();
    private final AtomicInteger dropped = new AtomicInteger();

    @Value("${matching.flush-interval-ms:30000}")
    private long flushIntervalMs;

    @Value("${matching.retention-days:14}")
    private int retentionDays;

    private static final int MAX_QUEUED = 200_000;

    public void offer(DriverLocation point) {
        if (pending.size() >= MAX_QUEUED) {
            // Losing trail history is better than growing the heap until the process dies.
            dropped.incrementAndGet();
            return;
        }
        pending.offer(point);
    }

    @Scheduled(fixedDelayString = "${matching.flush-interval-ms:30000}")
    @Transactional
    public void flush() {
        doFlush();
    }

    /**
     * Drains the queue in its own committed transaction. Called when a trip ends, because
     * the fare is measured from the stored trail and a few seconds of pings still buffered
     * in memory would otherwise be missing from it.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void flushNow() {
        doFlush();
    }

    private void doFlush() {
        if (pending.isEmpty()) return;
        List<DriverLocation> batch = new ArrayList<>();
        DriverLocation point;
        while (batch.size() < 5000 && (point = pending.poll()) != null) {
            batch.add(point);
        }
        if (batch.isEmpty()) return;
        driverLocationRepository.saveAll(batch);

        // One position write per driver per flush, not one per ping.
        Map<Long, DriverLocation> newestByDriver = new HashMap<>();
        for (DriverLocation located : batch) {
            newestByDriver.merge(located.getDriverId(), located,
                    (a, b) -> a.getRecordedAt().isAfter(b.getRecordedAt()) ? a : b);
        }
        newestByDriver.forEach((driverId, latest) -> driverRepository.refreshPosition(
                driverId, latest.getLatitude(), latest.getLongitude(), latest.getRecordedAt()));

        int lost = dropped.getAndSet(0);
        if (lost > 0) {
            log.warn("Flushed {} pings across {} drivers; {} dropped while the buffer was full",
                    batch.size(), newestByDriver.size(), lost);
        } else {
            log.debug("Flushed {} driver pings across {} drivers", batch.size(), newestByDriver.size());
        }
    }

    /** Keeps the time-series table bounded; runs once an hour. */
    @Scheduled(fixedDelay = 3_600_000L, initialDelay = 600_000L)
    @Transactional
    public void prune() {
        int removed = driverLocationRepository.deleteOlderThan(LocalDateTime.now().minusDays(retentionDays));
        if (removed > 0) log.info("Pruned {} driver_locations rows older than {} days", removed, retentionDays);
    }

    public int queued() {
        return pending.size();
    }
}
