package com.sentix.api.portfolio;

import lombok.Builder;

import java.math.BigDecimal;
import java.util.UUID;

@Builder
public record PortfolioHoldingResponse(
        UUID id,
        String symbol,
        String stockName,
        Integer quantity,
        BigDecimal averagePurchasePrice,
        BigDecimal currentPrice,
        BigDecimal currentValue,
        BigDecimal totalCostBasis,
        BigDecimal profitLoss,
        BigDecimal profitLossPercent,
        String currency) {
}
