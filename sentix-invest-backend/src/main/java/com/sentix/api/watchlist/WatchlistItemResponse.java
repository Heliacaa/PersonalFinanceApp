package com.sentix.api.watchlist;

import lombok.Builder;

import java.time.LocalDateTime;
import java.util.UUID;

@Builder
public record WatchlistItemResponse(
        UUID id,
        String symbol,
        String stockName,
        LocalDateTime addedAt,
        // Real-time data (fetched on demand)
        Double currentPrice,
        Double change,
        Double changePercent,
        String currency) {
}
