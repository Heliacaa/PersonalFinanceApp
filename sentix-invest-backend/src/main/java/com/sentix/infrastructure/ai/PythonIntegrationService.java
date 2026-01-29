package com.sentix.infrastructure.ai;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

@Service
@RequiredArgsConstructor
public class PythonIntegrationService {

    private final WebClient.Builder webClientBuilder;

    @Value("${mcp.server.url:http://mcp-server:8000}")
    private String mcpServerUrl;

    public Mono<String> analyzeSentiment(String text) {
        return webClientBuilder.build()
                .post()
                .uri(mcpServerUrl + "/analyze-sentiment")
                .bodyValue(new SentimentRequest(text))
                .retrieve()
                .bodyToMono(String.class);
    }

    record SentimentRequest(String text) {
    }
}
