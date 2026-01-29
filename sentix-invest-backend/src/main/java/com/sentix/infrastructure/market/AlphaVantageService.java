package com.sentix.infrastructure.market;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

@Service
@RequiredArgsConstructor
public class AlphaVantageService {

    @Value("${alphavantage.api-key}")
    private String apiKey;

    private final WebClient.Builder webClientBuilder;

    private static final String BASE_URL = "https://www.alphavantage.co/query";

    public String getDailyTimeSeries(String symbol) {
        return webClientBuilder.build()
                .get()
                .uri(uriBuilder -> uriBuilder
                        .scheme("https")
                        .host("www.alphavantage.co")
                        .path("/query")
                        .queryParam("function", "TIME_SERIES_DAILY")
                        .queryParam("symbol", symbol)
                        .queryParam("apikey", apiKey)
                        .build())
                .retrieve()
                .bodyToMono(String.class)
                .block();
    }
}
