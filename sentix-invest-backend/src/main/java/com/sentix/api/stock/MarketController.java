package com.sentix.api.stock;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/markets")
@RequiredArgsConstructor
public class MarketController {

    private final StockService stockService;

    @GetMapping("/summary")
    public ResponseEntity<MarketSummaryDto> getMarketSummary() {
        MarketSummaryDto summary = stockService.getMarketSummary();
        if (summary == null) {
            return ResponseEntity.internalServerError().build();
        }
        return ResponseEntity.ok(summary);
    }
}
