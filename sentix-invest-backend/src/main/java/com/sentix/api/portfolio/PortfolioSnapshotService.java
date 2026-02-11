package com.sentix.api.portfolio;

import com.sentix.api.stock.StockQuoteDto;
import com.sentix.api.stock.StockService;
import com.sentix.domain.PortfolioHolding;
import com.sentix.domain.PortfolioSnapshot;
import com.sentix.domain.User;
import com.sentix.infrastructure.persistence.PortfolioHoldingRepository;
import com.sentix.infrastructure.persistence.PortfolioSnapshotRepository;
import com.sentix.infrastructure.persistence.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class PortfolioSnapshotService {

    private final PortfolioSnapshotRepository snapshotRepository;
    private final PortfolioHoldingRepository holdingRepository;
    private final UserRepository userRepository;
    private final StockService stockService;

    /**
     * Nightly job at 1 AM to take portfolio snapshots for all users with holdings.
     */
    @Scheduled(cron = "${portfolio.snapshot.cron:0 0 1 * * *}")
    @Transactional
    public void takeNightlySnapshots() {
        log.info("Starting nightly portfolio snapshot job...");
        List<User> allUsers = userRepository.findAll();
        int snapshotCount = 0;

        for (User user : allUsers) {
            try {
                // Take snapshot for real portfolio
                List<PortfolioHolding> realHoldings = holdingRepository.findByUserAndIsPaper(user, false);
                if (!realHoldings.isEmpty()) {
                    takeSnapshot(user, realHoldings, false);
                    snapshotCount++;
                }

                // Take snapshot for paper portfolio
                List<PortfolioHolding> paperHoldings = holdingRepository.findByUserAndIsPaper(user, true);
                if (!paperHoldings.isEmpty()) {
                    takeSnapshot(user, paperHoldings, true);
                    snapshotCount++;
                }
            } catch (Exception e) {
                log.warn("Error taking snapshot for user {}: {}", user.getId(), e.getMessage());
            }
        }

        log.info("Nightly snapshot job completed. Created {} snapshots.", snapshotCount);
    }

    /**
     * Take a snapshot for a specific user after a trade.
     */
    @Transactional
    public void takeSnapshotForUser(User user, boolean isPaper) {
        List<PortfolioHolding> holdings = holdingRepository.findByUserAndIsPaper(user, isPaper);
        if (!holdings.isEmpty()) {
            takeSnapshot(user, holdings, isPaper);
        } else {
            // Record zero-value snapshot when all holdings are sold
            saveOrUpdateSnapshot(user, BigDecimal.ZERO, BigDecimal.ZERO,
                    isPaper ? user.getPaperBalance() : user.getBalance(), 0, isPaper);
        }
    }

    private void takeSnapshot(User user, List<PortfolioHolding> holdings, boolean isPaper) {
        BigDecimal totalValue = BigDecimal.ZERO;
        BigDecimal totalCostBasis = BigDecimal.ZERO;

        for (PortfolioHolding holding : holdings) {
            BigDecimal currentPrice = getCurrentPrice(holding.getSymbol());
            BigDecimal currentValue = currentPrice.multiply(BigDecimal.valueOf(holding.getQuantity()));
            totalValue = totalValue.add(currentValue);
            totalCostBasis = totalCostBasis.add(holding.getTotalCostBasis());
        }

        BigDecimal cashBalance = isPaper ? user.getPaperBalance() : user.getBalance();

        saveOrUpdateSnapshot(user, totalValue, totalCostBasis, cashBalance, holdings.size(), isPaper);
    }

    private void saveOrUpdateSnapshot(User user, BigDecimal totalValue, BigDecimal totalCostBasis,
                                       BigDecimal cashBalance, int holdingsCount, boolean isPaper) {
        LocalDate today = LocalDate.now();

        // Update existing snapshot for today if present, otherwise create new
        Optional<PortfolioSnapshot> existing = snapshotRepository.findByUserAndSnapshotDateAndIsPaper(user, today, isPaper);
        PortfolioSnapshot snapshot;

        if (existing.isPresent()) {
            snapshot = existing.get();
            snapshot.setTotalValue(totalValue.setScale(4, RoundingMode.HALF_UP));
            snapshot.setTotalCostBasis(totalCostBasis.setScale(4, RoundingMode.HALF_UP));
            snapshot.setCashBalance(cashBalance);
            snapshot.setHoldingsCount(holdingsCount);
        } else {
            snapshot = PortfolioSnapshot.builder()
                    .user(user)
                    .snapshotDate(today)
                    .totalValue(totalValue.setScale(4, RoundingMode.HALF_UP))
                    .totalCostBasis(totalCostBasis.setScale(4, RoundingMode.HALF_UP))
                    .cashBalance(cashBalance)
                    .holdingsCount(holdingsCount)
                    .isPaper(isPaper)
                    .build();
        }

        snapshotRepository.save(snapshot);
        log.debug("Saved portfolio snapshot for user {} on {} (paper={})", user.getId(), today, isPaper);
    }

    /**
     * Get real performance history from snapshots.
     */
    public List<PortfolioPerformanceResponse.PerformanceDataPoint> getPerformanceHistory(User user, int days, boolean isPaper) {
        LocalDate endDate = LocalDate.now();
        LocalDate startDate = endDate.minusDays(days);

        List<PortfolioSnapshot> snapshots = snapshotRepository
                .findByUserAndIsPaperAndSnapshotDateBetweenOrderBySnapshotDateAsc(user, isPaper, startDate, endDate);

        if (snapshots.isEmpty()) {
            return new ArrayList<>();
        }

        List<PortfolioPerformanceResponse.PerformanceDataPoint> history = new ArrayList<>();
        BigDecimal firstValue = snapshots.get(0).getTotalValue();

        for (PortfolioSnapshot snapshot : snapshots) {
            BigDecimal dailyReturn = BigDecimal.ZERO;
            BigDecimal cumulativeReturn = BigDecimal.ZERO;

            if (firstValue.compareTo(BigDecimal.ZERO) > 0) {
                cumulativeReturn = snapshot.getTotalValue().subtract(firstValue)
                        .divide(firstValue, 4, RoundingMode.HALF_UP)
                        .multiply(BigDecimal.valueOf(100));
            }

            // Calculate daily return from previous day
            int idx = snapshots.indexOf(snapshot);
            if (idx > 0) {
                BigDecimal prevValue = snapshots.get(idx - 1).getTotalValue();
                if (prevValue.compareTo(BigDecimal.ZERO) > 0) {
                    dailyReturn = snapshot.getTotalValue().subtract(prevValue)
                            .divide(prevValue, 4, RoundingMode.HALF_UP)
                            .multiply(BigDecimal.valueOf(100));
                }
            }

            history.add(PortfolioPerformanceResponse.PerformanceDataPoint.builder()
                    .date(snapshot.getSnapshotDate())
                    .portfolioValue(snapshot.getTotalValue().setScale(2, RoundingMode.HALF_UP))
                    .dailyReturn(dailyReturn.setScale(2, RoundingMode.HALF_UP))
                    .cumulativeReturn(cumulativeReturn.setScale(2, RoundingMode.HALF_UP))
                    .build());
        }

        return history;
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
