package com.sentix.api.trading;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record BuyRequest(
        @NotBlank(message = "Symbol is required") String symbol,

        @NotNull(message = "Quantity is required") @Min(value = 1, message = "Quantity must be at least 1") Integer quantity) {
}
