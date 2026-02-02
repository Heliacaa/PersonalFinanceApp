package com.sentix.api.stock;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.time.Duration;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class StockService {

    private final WebClient.Builder webClientBuilder;

    @Value("${mcp.server.url:http://localhost:8000}")
    private String mcpServerUrl;

    private WebClient getMcpClient() {
        return webClientBuilder.baseUrl(mcpServerUrl).build();
    }

    public StockQuoteDto getStockQuote(String symbol) {
        try {
            Map<String, Object> response = getMcpClient()
                    .get()
                    .uri("/stock/{symbol}", symbol)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(10))
                    .block();

            if (response == null) {
                return null;
            }

            return StockQuoteDto.builder()
                    .symbol((String) response.get("symbol"))
                    .name((String) response.get("name"))
                    .price(toDouble(response.get("price")))
                    .change(toDouble(response.get("change")))
                    .changePercent(toDouble(response.get("changePercent")))
                    .currency((String) response.get("currency"))
                    .marketState((String) response.get("marketState"))
                    .timestamp((String) response.get("timestamp"))
                    .build();
        } catch (Exception e) {
            log.error("Error fetching stock quote for {}: {}", symbol, e.getMessage());
            return null;
        }
    }

    public MarketSummaryDto getMarketSummary() {
        try {
            Map<String, Object> response = getMcpClient()
                    .get()
                    .uri("/market-summary")
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(15))
                    .block();

            if (response == null) {
                return null;
            }

            return MarketSummaryDto.builder()
                    .bist100(mapToMarketIndex((Map<String, Object>) response.get("bist100")))
                    .nasdaq(mapToMarketIndex((Map<String, Object>) response.get("nasdaq")))
                    .sp500(mapToMarketIndex((Map<String, Object>) response.get("sp500")))
                    .timestamp((String) response.get("timestamp"))
                    .build();
        } catch (Exception e) {
            log.error("Error fetching market summary: {}", e.getMessage());
            return null;
        }
    }

    public Map<String, Object> getStockHistory(String symbol, String period) {
        try {
            return getMcpClient()
                    .get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/stock/{symbol}/history")
                            .queryParam("period", period)
                            .build(symbol))
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(15))
                    .block();
        } catch (Exception e) {
            log.error("Error fetching stock history for {}: {}", symbol, e.getMessage());
            return null;
        }
    }

    public Map<String, Object> searchStocks(String query) {
        try {
            return getMcpClient()
                    .get()
                    .uri("/search/{query}", query)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(10))
                    .block();
        } catch (Exception e) {
            log.error("Error searching stocks for {}: {}", query, e.getMessage());
            return Map.of("results", java.util.List.of(), "query", query);
        }
    }

    public Map<String, Object> getStockNews(String symbol, int count) {
        try {
            return getMcpClient()
                    .get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/news/{symbol}")
                            .queryParam("count", count)
                            .build(symbol))
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(10))
                    .block();
        } catch (Exception e) {
            log.error("Error fetching news for {}: {}", symbol, e.getMessage());
            return Map.of("symbol", symbol, "stockName", symbol, "news", java.util.List.of());
        }
    }

    private MarketIndexDto mapToMarketIndex(Map<String, Object> data) {
        if (data == null) {
            return null;
        }
        return MarketIndexDto.builder()
                .symbol((String) data.get("symbol"))
                .name((String) data.get("name"))
                .price(toDouble(data.get("price")))
                .change(toDouble(data.get("change")))
                .changePercent(toDouble(data.get("changePercent")))
                .build();
    }

    private double toDouble(Object value) {
        if (value == null)
            return 0.0;
        if (value instanceof Number) {
            return ((Number) value).doubleValue();
        }
        try {
            return Double.parseDouble(value.toString());
        } catch (NumberFormatException e) {
            return 0.0;
        }
    }
}
