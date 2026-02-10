package com.sentix.api.crypto;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/crypto")
@RequiredArgsConstructor
public class CryptoController {

    private final CryptoService cryptoService;

    @GetMapping("/markets")
    public ResponseEntity<Map<String, Object>> getCryptoMarkets(
            @RequestParam(defaultValue = "20") int limit) {
        Map<String, Object> markets = cryptoService.getCryptoMarkets(limit);
        if (markets == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(markets);
    }

    @GetMapping("/quote/{symbol}")
    public ResponseEntity<Map<String, Object>> getCryptoQuote(@PathVariable String symbol) {
        Map<String, Object> quote = cryptoService.getCryptoQuote(symbol);
        if (quote == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(quote);
    }
}
