package com.sentix.api.stock;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class MarketIndexDto {
    private String symbol;
    private String name;
    private double price;
    private double change;
    private double changePercent;
}
