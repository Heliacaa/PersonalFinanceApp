package com.sentix.api.ai;

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
public class AIAnalysisService {

    private final WebClient.Builder webClientBuilder;

    @Value("${mcp.server.url:http://localhost:8000}")
    private String mcpServerUrl;

    private WebClient getMcpClient() {
        return webClientBuilder.baseUrl(mcpServerUrl).build();
    }

    public Map<String, Object> getAIAnalysis(String symbol) {
        try {
            return getMcpClient()
                    .get()
                    .uri("/ai/analyze/{symbol}", symbol)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(30))
                    .block();
        } catch (Exception e) {
            log.error("Error fetching AI analysis for {}: {}", symbol, e.getMessage());
            return null;
        }
    }
}
