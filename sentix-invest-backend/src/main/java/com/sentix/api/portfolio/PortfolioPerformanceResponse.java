package com.sentix.api.portfolio;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
@Builder
public class PortfolioPerformanceResponse {
    private BigDecimal currentValue;
    private BigDecimal totalInvested;
    private BigDecimal totalReturn;
    private BigDecimal totalReturnPercent;
    private BigDecimal dayChange;
    private BigDecimal dayChangePercent;
    private List<PerformanceDataPoint> performanceHistory;
    private List<AllocationByStock> allocationByStock;
    private List<AllocationBySector> allocationBySector;

    @Data
    @Builder
    public static class PerformanceDataPoint {
        private LocalDate date;
        private BigDecimal portfolioValue;
        private BigDecimal dailyReturn;
        private BigDecimal cumulativeReturn;
    }

    @Data
    @Builder
    public static class AllocationByStock {
        private String symbol;
        private String stockName;
        private BigDecimal value;
        private BigDecimal percentage;
        private BigDecimal profitLoss;
        private BigDecimal profitLossPercent;
    }

    @Data
    @Builder
    public static class AllocationBySector {
        private String sector;
        private BigDecimal value;
        private BigDecimal percentage;
        private int stockCount;
    }
}
