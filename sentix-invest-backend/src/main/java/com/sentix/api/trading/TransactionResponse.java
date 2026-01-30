package com.sentix.api.trading;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Builder
public record TransactionResponse(
        UUID id,
        String symbol,
        String stockName,
        String type,
        Integer quantity,
        BigDecimal pricePerShare,
        BigDecimal totalAmount,
        String currency,
        LocalDateTime executedAt) {
}
