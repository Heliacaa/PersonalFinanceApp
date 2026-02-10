package com.sentix.api.forex;

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
public class ForexService {

    private final WebClient.Builder webClientBuilder;

    @Value("${mcp.server.url:http://localhost:8000}")
    private String mcpServerUrl;

    private WebClient getMcpClient() {
        return webClientBuilder.baseUrl(mcpServerUrl).build();
    }

    public Map<String, Object> getForexRates(String base) {
        try {
            return getMcpClient()
                    .get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/forex/rates")
                            .queryParam("base", base)
                            .build())
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(15))
                    .block();
        } catch (Exception e) {
            log.error("Error fetching forex rates for base {}: {}", base, e.getMessage());
            return null;
        }
    }

    public Map<String, Object> convertCurrency(String fromCurrency, String toCurrency, double amount) {
        try {
            return getMcpClient()
                    .get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/forex/convert")
                            .queryParam("from_currency", fromCurrency)
                            .queryParam("to_currency", toCurrency)
                            .queryParam("amount", amount)
                            .build())
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(15))
                    .block();
        } catch (Exception e) {
            log.error("Error converting {} to {}: {}", fromCurrency, toCurrency, e.getMessage());
            return null;
        }
    }
}
