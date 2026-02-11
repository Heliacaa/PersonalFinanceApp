package com.sentix.api.portfolio;

import lombok.Builder;

import java.math.BigDecimal;
import java.util.List;

@Builder
public record PortfolioSummaryResponse(
        BigDecimal totalValue,
        BigDecimal totalCostBasis,
        BigDecimal totalProfitLoss,
        BigDecimal totalProfitLossPercent,
        BigDecimal cashBalance,
        int holdingsCount,
        String displayCurrency,
        List<AllocationItem> allocations) {
    @Builder
    public record AllocationItem(
            String symbol,
            String stockName,
            BigDecimal value,
            BigDecimal percentage) {
    }
}
