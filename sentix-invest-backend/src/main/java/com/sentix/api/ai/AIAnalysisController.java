package com.sentix.api.ai;

import com.sentix.domain.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/ai")
@RequiredArgsConstructor
public class AIAnalysisController {

    private final AIAnalysisService aiAnalysisService;

    @GetMapping("/analyze/{symbol}")
    public ResponseEntity<Map<String, Object>> getAIAnalysis(@PathVariable String symbol) {
        Map<String, Object> analysis = aiAnalysisService.getAIAnalysis(symbol);
        if (analysis == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(analysis);
    }

    /**
     * RAG-powered conversational AI chat.
     * Authenticated — enriches responses with user's portfolio context.
     */
    @PostMapping("/chat")
    public ResponseEntity<ChatResponse> chat(
            @RequestBody ChatRequest request,
            @AuthenticationPrincipal User user) {
        if (user == null) {
            return ResponseEntity.status(401).build();
        }
        ChatResponse response = aiAnalysisService.chat(request, user);
        if (response == null) {
            return ResponseEntity.internalServerError().build();
        }
        return ResponseEntity.ok(response);
    }

    /**
     * Get RAG system status (public, for monitoring).
     */
    @GetMapping("/rag/status")
    public ResponseEntity<Map<String, Object>> getRAGStatus() {
        return ResponseEntity.ok(aiAnalysisService.getRAGStatus());
    }
}
