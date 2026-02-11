package com.sentix.api.trading;

import com.sentix.api.common.PageResponse;
import com.sentix.domain.User;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/trading")
@RequiredArgsConstructor
public class TradingController {

    private final TradingService tradingService;

    @PostMapping("/buy")
    public ResponseEntity<TradeResponse> buyStock(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody BuyRequest request) {
        TradeResponse response = tradingService.buyStock(user, request);
        if (response.success()) {
            return ResponseEntity.ok(response);
        }
        return ResponseEntity.badRequest().body(response);
    }

    @PostMapping("/sell")
    public ResponseEntity<TradeResponse> sellStock(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody SellRequest request) {
        TradeResponse response = tradingService.sellStock(user, request);
        if (response.success()) {
            return ResponseEntity.ok(response);
        }
        return ResponseEntity.badRequest().body(response);
    }

    @GetMapping("/transactions")
    public ResponseEntity<PageResponse<TransactionResponse>> getTransactions(
            @AuthenticationPrincipal User user,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(tradingService.getTransactionsPaginated(user, PageRequest.of(page, size)));
    }

    @GetMapping("/transactions/{symbol}")
    public ResponseEntity<List<TransactionResponse>> getTransactionsBySymbol(
            @AuthenticationPrincipal User user,
            @PathVariable String symbol) {
        return ResponseEntity.ok(tradingService.getTransactionsBySymbol(user, symbol));
    }
}
