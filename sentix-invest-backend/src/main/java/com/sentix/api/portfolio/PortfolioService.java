package com.sentix.api.portfolio;

import com.sentix.api.stock.StockQuoteDto;
import com.sentix.api.stock.StockService;
import com.sentix.domain.PortfolioHolding;
import com.sentix.domain.User;
import com.sentix.infrastructure.persistence.PortfolioHoldingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class PortfolioService {

    private final PortfolioHoldingRepository portfolioHoldingRepository;
    private final StockService stockService;

    public List<PortfolioHoldingResponse> getPortfolio(User user) {
        List<PortfolioHolding> holdings = portfolioHoldingRepository.findByUser(user);
        List<PortfolioHoldingResponse> responses = new ArrayList<>();

        for (PortfolioHolding holding : holdings) {
            responses.add(buildHoldingResponse(holding));
        }

        return responses;
    }

    public PortfolioSummaryResponse getPortfolioSummary(User user) {
        List<PortfolioHolding> holdings = portfolioHoldingRepository.findByUser(user);

        BigDecimal totalValue = BigDecimal.ZERO;
        BigDecimal totalCostBasis = BigDecimal.ZERO;
        List<PortfolioSummaryResponse.AllocationItem> allocations = new ArrayList<>();

        for (PortfolioHolding holding : holdings) {
            BigDecimal currentPrice = getCurrentPrice(holding.getSymbol());
            BigDecimal currentValue = currentPrice.multiply(BigDecimal.valueOf(holding.getQuantity()));
            BigDecimal costBasis = holding.getTotalCostBasis();

            totalValue = totalValue.add(currentValue);
            totalCostBasis = totalCostBasis.add(costBasis);

            allocations.add(PortfolioSummaryResponse.AllocationItem.builder()
                    .symbol(holding.getSymbol())
                    .stockName(holding.getStockName())
                    .value(currentValue)
                    .percentage(BigDecimal.ZERO) // Will be calculated after totals
                    .build());
        }

        // Calculate percentages
        BigDecimal finalTotalValue = totalValue;
        if (totalValue.compareTo(BigDecimal.ZERO) > 0) {
            allocations = allocations.stream()
                    .map(a -> PortfolioSummaryResponse.AllocationItem.builder()
                            .symbol(a.symbol())
                            .stockName(a.stockName())
                            .value(a.value())
                            .percentage(a.value()
                                    .divide(finalTotalValue, 4, RoundingMode.HALF_UP)
                                    .multiply(BigDecimal.valueOf(100)))
                            .build())
                    .toList();
        }

        BigDecimal totalProfitLoss = totalValue.subtract(totalCostBasis);
        BigDecimal totalProfitLossPercent = BigDecimal.ZERO;
        if (totalCostBasis.compareTo(BigDecimal.ZERO) > 0) {
            totalProfitLossPercent = totalProfitLoss
                    .divide(totalCostBasis, 4, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100));
        }

        return PortfolioSummaryResponse.builder()
                .totalValue(totalValue.setScale(2, RoundingMode.HALF_UP))
                .totalCostBasis(totalCostBasis.setScale(2, RoundingMode.HALF_UP))
                .totalProfitLoss(totalProfitLoss.setScale(2, RoundingMode.HALF_UP))
                .totalProfitLossPercent(totalProfitLossPercent.setScale(2, RoundingMode.HALF_UP))
                .cashBalance(user.getBalance())
                .holdingsCount(holdings.size())
                .allocations(allocations)
                .build();
    }

    public PortfolioHoldingResponse getHoldingBySymbol(User user, String symbol) {
        return portfolioHoldingRepository.findByUserAndSymbol(user, symbol.toUpperCase())
                .map(this::buildHoldingResponse)
                .orElse(null);
    }

    private PortfolioHoldingResponse buildHoldingResponse(PortfolioHolding holding) {
        BigDecimal currentPrice = getCurrentPrice(holding.getSymbol());
        BigDecimal currentValue = currentPrice.multiply(BigDecimal.valueOf(holding.getQuantity()));
        BigDecimal totalCostBasis = holding.getTotalCostBasis();
        BigDecimal profitLoss = currentValue.subtract(totalCostBasis);
        BigDecimal profitLossPercent = BigDecimal.ZERO;

        if (totalCostBasis.compareTo(BigDecimal.ZERO) > 0) {
            profitLossPercent = profitLoss
                    .divide(totalCostBasis, 4, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100));
        }

        return PortfolioHoldingResponse.builder()
                .id(holding.getId())
                .symbol(holding.getSymbol())
                .stockName(holding.getStockName())
                .quantity(holding.getQuantity())
                .averagePurchasePrice(holding.getAveragePurchasePrice().setScale(2, RoundingMode.HALF_UP))
                .currentPrice(currentPrice.setScale(2, RoundingMode.HALF_UP))
                .currentValue(currentValue.setScale(2, RoundingMode.HALF_UP))
                .totalCostBasis(totalCostBasis.setScale(2, RoundingMode.HALF_UP))
                .profitLoss(profitLoss.setScale(2, RoundingMode.HALF_UP))
                .profitLossPercent(profitLossPercent.setScale(2, RoundingMode.HALF_UP))
                .currency(holding.getCurrency())
                .build();
    }

    private BigDecimal getCurrentPrice(String symbol) {
        try {
            StockQuoteDto quote = stockService.getStockQuote(symbol);
            if (quote != null) {
                return BigDecimal.valueOf(quote.getPrice());
            }
        } catch (Exception e) {
            log.warn("Could not fetch current price for {}: {}", symbol, e.getMessage());
        }
        return BigDecimal.ZERO;
    }
}
