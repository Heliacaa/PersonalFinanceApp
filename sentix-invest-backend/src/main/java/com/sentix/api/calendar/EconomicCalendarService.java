package com.sentix.api.calendar;

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
public class EconomicCalendarService {

    private final WebClient.Builder webClientBuilder;

    @Value("${mcp.server.url:http://localhost:8000}")
    private String mcpServerUrl;

    private WebClient getMcpClient() {
        return webClientBuilder.baseUrl(mcpServerUrl).build();
    }

    public Map<String, Object> getEconomicCalendar(int days) {
        try {
            return getMcpClient()
                    .get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/calendar/economic")
                            .queryParam("days", days)
                            .build())
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(15))
                    .block();
        } catch (Exception e) {
            log.error("Error fetching economic calendar: {}", e.getMessage());
            return null;
        }
    }
}
