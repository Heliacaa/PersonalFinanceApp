package com.sentix.api.portfolio;

import com.sentix.domain.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/portfolio")
@RequiredArgsConstructor
public class PortfolioController {

    private final PortfolioService portfolioService;

    @GetMapping
    public ResponseEntity<List<PortfolioHoldingResponse>> getPortfolio(
            @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(portfolioService.getPortfolio(user));
    }

    @GetMapping("/summary")
    public ResponseEntity<PortfolioSummaryResponse> getPortfolioSummary(
            @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(portfolioService.getPortfolioSummary(user));
    }

    @GetMapping("/{symbol}")
    public ResponseEntity<PortfolioHoldingResponse> getHoldingBySymbol(
            @AuthenticationPrincipal User user,
            @PathVariable String symbol) {
        PortfolioHoldingResponse holding = portfolioService.getHoldingBySymbol(user, symbol);
        if (holding == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(holding);
    }
}
