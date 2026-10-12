package com.rideet.dto.response;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDate;
import java.util.List;

/**
 * Daily trend for the dashboard charts. Every day in the window is present, including days with
 * no activity, so the x-axis is the window and not just the days something happened to happen.
 */
@Data
@Builder
public class AdminDailyStatsResponse {

    private int windowDays;
    private long totalRides;
    private double totalRevenue;
    private List<Day> days;

    @Data
    @Builder
    public static class Day {
        private LocalDate date;
        private long rides;
        private double revenue;
    }
}
