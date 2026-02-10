package com.sentix.api.crypto;

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
public class CryptoService {

    private final WebClient.Builder webClientBuilder;

    @Value("${mcp.server.url:http://localhost:8000}")
    private String mcpServerUrl;

    private WebClient getMcpClient() {
        return webClientBuilder.baseUrl(mcpServerUrl).build();
    }

    public Map<String, Object> getCryptoMarkets(int limit) {
        try {
            return getMcpClient()
                    .get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/crypto/markets")
                            .queryParam("limit", limit)
                            .build())
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(15))
                    .block();
        } catch (Exception e) {
            log.error("Error fetching crypto markets: {}", e.getMessage());
            return null;
        }
    }

    public Map<String, Object> getCryptoQuote(String symbol) {
        try {
            return getMcpClient()
                    .get()
                    .uri("/crypto/quote/{symbol}", symbol)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(10))
                    .block();
        } catch (Exception e) {
            log.error("Error fetching crypto quote for {}: {}", symbol, e.getMessage());
            return null;
        }
    }
}
