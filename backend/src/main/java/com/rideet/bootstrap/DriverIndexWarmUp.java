package com.rideet.bootstrap;

import com.rideet.matching.MatchingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * The live driver index is in memory, so a restart would leave every already-online driver
 * invisible to matching until they next ping — which for a driver sitting in a depot could
 * be minutes. Rebuild it from the last persisted position instead.
 *
 * <p>Runs on ApplicationReadyEvent, after the seeders, so freshly created dev drivers are
 * included.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DriverIndexWarmUp {

    private final MatchingService matchingService;

    @EventListener(ApplicationReadyEvent.class)
    public void warmUp() {
        int loaded = matchingService.reindexFromDatabase();
        log.info("Driver index warm-up complete: {} online drivers matchable", loaded);
    }
}
