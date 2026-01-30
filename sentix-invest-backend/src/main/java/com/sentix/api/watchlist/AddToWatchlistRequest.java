package com.sentix.api.watchlist;

import jakarta.validation.constraints.NotBlank;

public record AddToWatchlistRequest(
        @NotBlank(message = "Symbol is required") String symbol,

        @NotBlank(message = "Stock name is required") String stockName) {
}
