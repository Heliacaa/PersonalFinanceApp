package com.sentix.api.alert;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class CreateAlertRequest {
    @NotBlank(message = "Symbol is required")
    private String symbol;

    @NotBlank(message = "Stock name is required")
    private String stockName;

    @NotNull(message = "Target price is required")
    @Positive(message = "Target price must be positive")
    private BigDecimal targetPrice;

    @NotBlank(message = "Alert type is required")
    private String alertType; // "ABOVE" or "BELOW"
}
