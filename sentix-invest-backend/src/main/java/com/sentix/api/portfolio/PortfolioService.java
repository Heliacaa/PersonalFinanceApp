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

    /**
     * Get portfolio performance analytics including allocations and simulated
     * performance history
     */
    public PortfolioPerformanceResponse getPerformanceAnalytics(User user) {
        List<PortfolioHolding> holdings = portfolioHoldingRepository.findByUser(user);

        BigDecimal totalValue = BigDecimal.ZERO;
        BigDecimal totalInvested = BigDecimal.ZERO;
        BigDecimal dayChange = BigDecimal.ZERO;

        List<PortfolioPerformanceResponse.AllocationByStock> stockAllocations = new ArrayList<>();

        // Calculate current values and allocations
        for (PortfolioHolding holding : holdings) {
            BigDecimal currentPrice = getCurrentPrice(holding.getSymbol());
            BigDecimal currentValue = currentPrice.multiply(BigDecimal.valueOf(holding.getQuantity()));
            BigDecimal costBasis = holding.getTotalCostBasis();
            BigDecimal profitLoss = currentValue.subtract(costBasis);
            BigDecimal profitLossPercent = BigDecimal.ZERO;

            if (costBasis.compareTo(BigDecimal.ZERO) > 0) {
                profitLossPercent = profitLoss
                        .divide(costBasis, 4, RoundingMode.HALF_UP)
                        .multiply(BigDecimal.valueOf(100));
            }

            totalValue = totalValue.add(currentValue);
            totalInvested = totalInvested.add(costBasis);

            // Get day change from stock quote
            try {
                StockQuoteDto quote = stockService.getStockQuote(holding.getSymbol());
                if (quote != null) {
                    dayChange = dayChange.add(
                            BigDecimal.valueOf(quote.getChange())
                                    .multiply(BigDecimal.valueOf(holding.getQuantity())));
                }
            } catch (Exception e) {
                log.debug("Could not get day change for {}", holding.getSymbol());
            }

            stockAllocations.add(PortfolioPerformanceResponse.AllocationByStock.builder()
                    .symbol(holding.getSymbol())
                    .stockName(holding.getStockName())
                    .value(currentValue.setScale(2, RoundingMode.HALF_UP))
                    .percentage(BigDecimal.ZERO) // Will be calculated after totals
                    .profitLoss(profitLoss.setScale(2, RoundingMode.HALF_UP))
                    .profitLossPercent(profitLossPercent.setScale(2, RoundingMode.HALF_UP))
                    .build());
        }

        // Calculate allocation percentages
        BigDecimal finalTotalValue = totalValue;
        if (totalValue.compareTo(BigDecimal.ZERO) > 0) {
            stockAllocations = stockAllocations.stream()
                    .map(a -> PortfolioPerformanceResponse.AllocationByStock.builder()
                            .symbol(a.getSymbol())
                            .stockName(a.getStockName())
                            .value(a.getValue())
                            .percentage(a.getValue()
                                    .divide(finalTotalValue, 4, RoundingMode.HALF_UP)
                                    .multiply(BigDecimal.valueOf(100))
                                    .setScale(2, RoundingMode.HALF_UP))
                            .profitLoss(a.getProfitLoss())
                            .profitLossPercent(a.getProfitLossPercent())
                            .build())
                    .toList();
        }

        // Calculate total returns
        BigDecimal totalReturn = totalValue.subtract(totalInvested);
        BigDecimal totalReturnPercent = BigDecimal.ZERO;
        if (totalInvested.compareTo(BigDecimal.ZERO) > 0) {
            totalReturnPercent = totalReturn
                    .divide(totalInvested, 4, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100));
        }

        BigDecimal dayChangePercent = BigDecimal.ZERO;
        if (totalValue.subtract(dayChange).compareTo(BigDecimal.ZERO) > 0) {
            dayChangePercent = dayChange
                    .divide(totalValue.subtract(dayChange), 4, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100));
        }

        // Generate simulated performance history (last 30 days)
        List<PortfolioPerformanceResponse.PerformanceDataPoint> performanceHistory = generatePerformanceHistory(
                totalValue, totalReturnPercent);

        return PortfolioPerformanceResponse.builder()
                .currentValue(totalValue.setScale(2, RoundingMode.HALF_UP))
                .totalInvested(totalInvested.setScale(2, RoundingMode.HALF_UP))
                .totalReturn(totalReturn.setScale(2, RoundingMode.HALF_UP))
                .totalReturnPercent(totalReturnPercent.setScale(2, RoundingMode.HALF_UP))
                .dayChange(dayChange.setScale(2, RoundingMode.HALF_UP))
                .dayChangePercent(dayChangePercent.setScale(2, RoundingMode.HALF_UP))
                .performanceHistory(performanceHistory)
                .allocationByStock(stockAllocations)
                .allocationBySector(new ArrayList<>()) // Sector data would require additional stock info
                .build();
    }

    /**
     * Generate simulated performance history based on current portfolio value
     * In production, this would query transaction history and calculate actual
     * daily values
     */
    private List<PortfolioPerformanceResponse.PerformanceDataPoint> generatePerformanceHistory(
            BigDecimal currentValue, BigDecimal totalReturnPercent) {
        List<PortfolioPerformanceResponse.PerformanceDataPoint> history = new ArrayList<>();
        java.time.LocalDate today = java.time.LocalDate.now();

        // Simulate 30 days of history with gradual approach to current value
        double currentValueDouble = currentValue.doubleValue();
        double totalReturnDouble = totalReturnPercent.doubleValue();

        for (int i = 29; i >= 0; i--) {
            java.time.LocalDate date = today.minusDays(i);

            // Simulate gradual growth/decline with some variance
            double progress = (30.0 - i) / 30.0;
            double variance = (Math.random() - 0.5) * 2.0; // Random variance ±1%
            double dailyReturn = (totalReturnDouble * progress / 30) + variance;
            double cumulativeReturn = totalReturnDouble * progress;
            double portfolioValue = currentValueDouble * (1 - (totalReturnDouble / 100) * (1 - progress));

            history.add(PortfolioPerformanceResponse.PerformanceDataPoint.builder()
                    .date(date)
                    .portfolioValue(BigDecimal.valueOf(portfolioValue).setScale(2, RoundingMode.HALF_UP))
                    .dailyReturn(BigDecimal.valueOf(dailyReturn).setScale(2, RoundingMode.HALF_UP))
                    .cumulativeReturn(BigDecimal.valueOf(cumulativeReturn).setScale(2, RoundingMode.HALF_UP))
                    .build());
        }

        return history;
    }
}
