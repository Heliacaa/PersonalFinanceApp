package com.sentix.api.trading;

import lombok.Builder;

import java.math.BigDecimal;

@Builder
public record TradeResponse(
        boolean success,
        String message,
        TransactionResponse transaction,
        BigDecimal newBalance) {
}
