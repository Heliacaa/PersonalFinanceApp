package com.sentix.api.ai;

import com.sentix.domain.PortfolioHolding;
import com.sentix.domain.User;
import com.sentix.domain.Watchlist;
import com.sentix.infrastructure.persistence.PortfolioHoldingRepository;
import com.sentix.infrastructure.persistence.WatchlistRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.time.Duration;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class AIAnalysisService {

    private final WebClient.Builder webClientBuilder;
    private final PortfolioHoldingRepository portfolioHoldingRepository;
    private final WatchlistRepository watchlistRepository;

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

    /**
     * Send a chat message to the MCP server's RAG-powered chat endpoint.
     * Enriches the request with the user's portfolio and watchlist context.
     */
    public ChatResponse chat(ChatRequest request, User user) {
        try {
            // Build user context from portfolio and watchlist
            Map<String, Object> userContext = buildUserContext(user);
            userContext.put("userId", user.getId().toString());

            // Build MCP request body
            Map<String, Object> mcpRequest = new HashMap<>();
            mcpRequest.put("message", request.getMessage());
            mcpRequest.put("session_id", request.getSessionId());
            mcpRequest.put("user_context", userContext);
            if (request.getSymbol() != null && !request.getSymbol().isBlank()) {
                mcpRequest.put("symbol", request.getSymbol());
            }

            return getMcpClient()
                    .post()
                    .uri("/ai/chat")
                    .bodyValue(mcpRequest)
                    .retrieve()
                    .bodyToMono(ChatResponse.class)
                    .timeout(Duration.ofSeconds(30))
                    .block();
        } catch (Exception e) {
            log.error("Error in AI chat: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Get RAG system status from MCP server.
     */
    public Map<String, Object> getRAGStatus() {
        try {
            return getMcpClient()
                    .get()
                    .uri("/ai/rag/status")
                    .retrieve()
                    .bodyToMono(Map.class)
                    .timeout(Duration.ofSeconds(10))
                    .block();
        } catch (Exception e) {
            log.error("Error fetching RAG status: {}", e.getMessage());
            return Map.of("enabled", false, "error", e.getMessage());
        }
    }

    /**
     * Build user investment context from DB for personalized AI responses.
     */
    private Map<String, Object> buildUserContext(User user) {
        Map<String, Object> context = new HashMap<>();

        try {
            // Portfolio holdings
            List<PortfolioHolding> holdings = portfolioHoldingRepository.findByUser(user);
            List<Map<String, Object>> portfolioList = new ArrayList<>();
            for (PortfolioHolding h : holdings) {
                Map<String, Object> holdingMap = new HashMap<>();
                holdingMap.put("symbol", h.getSymbol());
                holdingMap.put("stockName", h.getStockName());
                holdingMap.put("quantity", h.getQuantity());
                holdingMap.put("averagePurchasePrice", h.getAveragePurchasePrice().doubleValue());
                portfolioList.add(holdingMap);
            }
            context.put("portfolio", portfolioList);

            // Watchlist
            List<Watchlist> watchlistItems = watchlistRepository.findByUser(user);
            List<Map<String, Object>> watchlistList = new ArrayList<>();
            for (Watchlist w : watchlistItems) {
                Map<String, Object> wMap = new HashMap<>();
                wMap.put("symbol", w.getSymbol());
                wMap.put("stockName", w.getStockName());
                watchlistList.add(wMap);
            }
            context.put("watchlist", watchlistList);
        } catch (Exception e) {
            log.warn("Error building user context: {}", e.getMessage());
        }

        return context;
    }
}
