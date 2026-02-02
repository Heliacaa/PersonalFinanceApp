package com.sentix.api.stock;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/stocks")
@RequiredArgsConstructor
public class StockController {

    private final StockService stockService;

    @GetMapping("/{symbol}")
    public ResponseEntity<StockQuoteDto> getStockQuote(@PathVariable String symbol) {
        StockQuoteDto quote = stockService.getStockQuote(symbol);
        if (quote == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(quote);
    }

    @GetMapping("/{symbol}/history")
    public ResponseEntity<Map<String, Object>> getStockHistory(
            @PathVariable String symbol,
            @RequestParam(defaultValue = "1mo") String period) {
        Map<String, Object> history = stockService.getStockHistory(symbol, period);
        if (history == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(history);
    }

    @GetMapping("/search/{query}")
    public ResponseEntity<Map<String, Object>> searchStocks(@PathVariable String query) {
        return ResponseEntity.ok(stockService.searchStocks(query));
    }

    @GetMapping("/{symbol}/news")
    public ResponseEntity<Map<String, Object>> getStockNews(
            @PathVariable String symbol,
            @RequestParam(defaultValue = "5") int count) {
        Map<String, Object> news = stockService.getStockNews(symbol, count);
        return ResponseEntity.ok(news);
    }
}
