package com.rideet.dto.response;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * What a driver has actually earned. Every number here is summed from COMPLETED rides or counted
 * from real offer answers — there is no payout rail behind the wallet figure, it is the driver's
 * account balance.
 */
@Data
@Builder
public class DriverEarningsResponse {

    private Double todayEarnings;
    private Double windowEarnings;
    private Double lifetimeEarnings;
    private Double walletBalance;

    private Integer todayRides;
    private Integer windowRides;
    private Integer totalRides;

    /** How many days the window and {@code days} list cover. */
    private Integer windowDays;

    private Double rating;
    private Integer totalRatings;

    /** Accepted offers as a percentage of the offers this driver answered; null until they answer one. */
    private Integer acceptanceRatePercent;

    /** One entry per day for the requested window, oldest first, including zero days. */
    private List<DayEarnings> days;

    @Data
    @Builder
    public static class DayEarnings {
        private String date;
        private Integer rides;
        private Double amount;
    }
}
