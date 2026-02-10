package com.sentix.api.forex;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/forex")
@RequiredArgsConstructor
public class ForexController {

    private final ForexService forexService;

    @GetMapping("/rates")
    public ResponseEntity<Map<String, Object>> getForexRates(
            @RequestParam(defaultValue = "USD") String base) {
        Map<String, Object> rates = forexService.getForexRates(base);
        if (rates == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(rates);
    }

    @GetMapping("/convert")
    public ResponseEntity<Map<String, Object>> convertCurrency(
            @RequestParam("from_currency") String fromCurrency,
            @RequestParam("to_currency") String toCurrency,
            @RequestParam double amount) {
        Map<String, Object> result = forexService.convertCurrency(fromCurrency, toCurrency, amount);
        if (result == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(result);
    }
}
