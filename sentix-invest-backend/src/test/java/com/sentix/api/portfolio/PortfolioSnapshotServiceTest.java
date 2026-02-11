package com.sentix.api.portfolio;

import com.sentix.api.stock.StockQuoteDto;
import com.sentix.api.stock.StockService;
import com.sentix.domain.PortfolioHolding;
import com.sentix.domain.PortfolioSnapshot;
import com.sentix.domain.User;
import com.sentix.infrastructure.persistence.PortfolioHoldingRepository;
import com.sentix.infrastructure.persistence.PortfolioSnapshotRepository;
import com.sentix.infrastructure.persistence.UserRepository;
import com.sentix.test.TestDataFactory;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PortfolioSnapshotServiceTest {

    @Mock private PortfolioSnapshotRepository snapshotRepository;
    @Mock private PortfolioHoldingRepository holdingRepository;
    @Mock private UserRepository userRepository;
    @Mock private StockService stockService;

    @InjectMocks
    private PortfolioSnapshotService snapshotService;

    private User testUser;

    @BeforeEach
    void setUp() {
        testUser = TestDataFactory.createUser();
    }

    @Test
    @DisplayName("takeSnapshotForUser creates a new snapshot with correct values")
    void takeSnapshotForUser_createsNewSnapshot() {
        PortfolioHolding holding = TestDataFactory.createHolding(
                testUser, "AAPL", "Apple Inc.", 10, new BigDecimal("150.00"), false);

        when(holdingRepository.findByUserAndIsPaper(testUser, false)).thenReturn(List.of(holding));
        when(stockService.getStockQuote("AAPL")).thenReturn(
                TestDataFactory.createStockQuote("AAPL", "Apple Inc.", 180.0));
        when(snapshotRepository.findByUserAndSnapshotDateAndIsPaper(eq(testUser), any(LocalDate.class), eq(false)))
                .thenReturn(Optional.empty());
        when(snapshotRepository.save(any(PortfolioSnapshot.class))).thenAnswer(i -> i.getArgument(0));

        snapshotService.takeSnapshotForUser(testUser, false);

        ArgumentCaptor<PortfolioSnapshot> captor = ArgumentCaptor.forClass(PortfolioSnapshot.class);
        verify(snapshotRepository).save(captor.capture());

        PortfolioSnapshot saved = captor.getValue();
        // 180 * 10 = 1800
        assertThat(saved.getTotalValue()).isEqualByComparingTo(new BigDecimal("1800"));
        // 150 * 10 = 1500
        assertThat(saved.getTotalCostBasis()).isEqualByComparingTo(new BigDecimal("1500"));
        assertThat(saved.getHoldingsCount()).isEqualTo(1);
        assertThat(saved.getIsPaper()).isFalse();
    }

    @Test
    @DisplayName("takeSnapshotForUser updates existing snapshot for same day")
    void takeSnapshotForUser_updatesExistingSnapshot() {
        PortfolioHolding holding = TestDataFactory.createHolding(
                testUser, "AAPL", "Apple Inc.", 10, new BigDecimal("150.00"), false);

        PortfolioSnapshot existingSnapshot = PortfolioSnapshot.builder()
                .user(testUser)
                .snapshotDate(LocalDate.now())
                .totalValue(new BigDecimal("1700.0000"))
                .totalCostBasis(new BigDecimal("1500.0000"))
                .cashBalance(new BigDecimal("10000.00"))
                .holdingsCount(1)
                .isPaper(false)
                .build();

        when(holdingRepository.findByUserAndIsPaper(testUser, false)).thenReturn(List.of(holding));
        when(stockService.getStockQuote("AAPL")).thenReturn(
                TestDataFactory.createStockQuote("AAPL", "Apple Inc.", 185.0));
        when(snapshotRepository.findByUserAndSnapshotDateAndIsPaper(eq(testUser), any(LocalDate.class), eq(false)))
                .thenReturn(Optional.of(existingSnapshot));
        when(snapshotRepository.save(any(PortfolioSnapshot.class))).thenAnswer(i -> i.getArgument(0));

        snapshotService.takeSnapshotForUser(testUser, false);

        verify(snapshotRepository).save(existingSnapshot);
        // Updated value: 185 * 10 = 1850
        assertThat(existingSnapshot.getTotalValue()).isEqualByComparingTo(new BigDecimal("1850"));
    }

    @Test
    @DisplayName("takeSnapshotForUser records zero snapshot when no holdings")
    void takeSnapshotForUser_noHoldings_recordsZeroSnapshot() {
        when(holdingRepository.findByUserAndIsPaper(testUser, false)).thenReturn(List.of());
        when(snapshotRepository.findByUserAndSnapshotDateAndIsPaper(eq(testUser), any(LocalDate.class), eq(false)))
                .thenReturn(Optional.empty());
        when(snapshotRepository.save(any(PortfolioSnapshot.class))).thenAnswer(i -> i.getArgument(0));

        snapshotService.takeSnapshotForUser(testUser, false);

        ArgumentCaptor<PortfolioSnapshot> captor = ArgumentCaptor.forClass(PortfolioSnapshot.class);
        verify(snapshotRepository).save(captor.capture());

        assertThat(captor.getValue().getTotalValue()).isEqualByComparingTo(BigDecimal.ZERO);
        assertThat(captor.getValue().getHoldingsCount()).isEqualTo(0);
    }

    @Test
    @DisplayName("takeNightlySnapshots processes both real and paper portfolios")
    void takeNightlySnapshots_processesBothPortfolioTypes() {
        PortfolioHolding realHolding = TestDataFactory.createHolding(
                testUser, "AAPL", "Apple Inc.", 5, new BigDecimal("150.00"), false);
        PortfolioHolding paperHolding = TestDataFactory.createHolding(
                testUser, "TSLA", "Tesla Inc.", 10, new BigDecimal("200.00"), true);

        when(userRepository.findAll()).thenReturn(List.of(testUser));
        when(holdingRepository.findByUserAndIsPaper(testUser, false)).thenReturn(List.of(realHolding));
        when(holdingRepository.findByUserAndIsPaper(testUser, true)).thenReturn(List.of(paperHolding));
        when(stockService.getStockQuote("AAPL")).thenReturn(
                TestDataFactory.createStockQuote("AAPL", "Apple Inc.", 180.0));
        when(stockService.getStockQuote("TSLA")).thenReturn(
                TestDataFactory.createStockQuote("TSLA", "Tesla Inc.", 250.0));
        when(snapshotRepository.findByUserAndSnapshotDateAndIsPaper(eq(testUser), any(LocalDate.class), anyBoolean()))
                .thenReturn(Optional.empty());
        when(snapshotRepository.save(any(PortfolioSnapshot.class))).thenAnswer(i -> i.getArgument(0));

        snapshotService.takeNightlySnapshots();

        // 2 snapshots: 1 real + 1 paper
        verify(snapshotRepository, times(2)).save(any(PortfolioSnapshot.class));
    }

    @Test
    @DisplayName("getPerformanceHistory returns correct data points with returns")
    void getPerformanceHistory_returnsCorrectDataPoints() {
        LocalDate today = LocalDate.now();

        PortfolioSnapshot snap1 = PortfolioSnapshot.builder()
                .user(testUser).snapshotDate(today.minusDays(2))
                .totalValue(new BigDecimal("1000.0000")).isPaper(false).build();
        PortfolioSnapshot snap2 = PortfolioSnapshot.builder()
                .user(testUser).snapshotDate(today.minusDays(1))
                .totalValue(new BigDecimal("1100.0000")).isPaper(false).build();
        PortfolioSnapshot snap3 = PortfolioSnapshot.builder()
                .user(testUser).snapshotDate(today)
                .totalValue(new BigDecimal("1050.0000")).isPaper(false).build();

        when(snapshotRepository.findByUserAndIsPaperAndSnapshotDateBetweenOrderBySnapshotDateAsc(
                eq(testUser), eq(false), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(snap1, snap2, snap3));

        List<PortfolioPerformanceResponse.PerformanceDataPoint> history =
                snapshotService.getPerformanceHistory(testUser, 7, false);

        assertThat(history).hasSize(3);

        // First point: cumulative return = 0 (baseline)
        assertThat(history.get(0).getCumulativeReturn()).isEqualByComparingTo(BigDecimal.ZERO);

        // Second point: daily return = 10% (1100-1000)/1000, cumulative = 10%
        assertThat(history.get(1).getDailyReturn()).isEqualByComparingTo(new BigDecimal("10.00"));
        assertThat(history.get(1).getCumulativeReturn()).isEqualByComparingTo(new BigDecimal("10.00"));

        // Third point: daily return = -4.55% (1050-1100)/1100, cumulative = 5%
        assertThat(history.get(2).getCumulativeReturn()).isEqualByComparingTo(new BigDecimal("5.00"));
    }

    @Test
    @DisplayName("getPerformanceHistory returns empty list when no snapshots")
    void getPerformanceHistory_noSnapshots_returnsEmpty() {
        when(snapshotRepository.findByUserAndIsPaperAndSnapshotDateBetweenOrderBySnapshotDateAsc(
                eq(testUser), eq(false), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of());

        List<PortfolioPerformanceResponse.PerformanceDataPoint> history =
                snapshotService.getPerformanceHistory(testUser, 30, false);

        assertThat(history).isEmpty();
    }
}
