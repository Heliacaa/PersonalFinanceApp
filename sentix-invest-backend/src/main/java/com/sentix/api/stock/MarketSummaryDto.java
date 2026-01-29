package com.sentix.api.stock;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class MarketSummaryDto {
    private MarketIndexDto bist100;
    private MarketIndexDto nasdaq;
    private MarketIndexDto sp500;
    private String timestamp;
}
