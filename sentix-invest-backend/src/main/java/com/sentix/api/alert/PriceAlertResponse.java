package com.sentix.api.alert;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class PriceAlertResponse {
    private UUID id;
    private String symbol;
    private String stockName;
    private BigDecimal targetPrice;
    private BigDecimal currentPrice;
    private String alertType;
    private Boolean isActive;
    private LocalDateTime createdAt;
    private LocalDateTime triggeredAt;
    private BigDecimal referencePrice;
    private Integer daysNotice;
}
