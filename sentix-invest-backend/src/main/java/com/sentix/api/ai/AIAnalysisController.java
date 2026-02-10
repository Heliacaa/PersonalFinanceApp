package com.sentix.api.ai;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
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
}
