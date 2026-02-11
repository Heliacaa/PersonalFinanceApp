package com.sentix.api.trading;

import com.sentix.api.portfolio.PortfolioSnapshotService;
import com.sentix.api.stock.StockQuoteDto;
import com.sentix.api.stock.StockService;
import com.sentix.domain.*;
import com.sentix.infrastructure.persistence.PortfolioHoldingRepository;
import com.sentix.infrastructure.persistence.TransactionRepository;
import com.sentix.infrastructure.persistence.UserRepository;
import com.sentix.test.TestDataFactory;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TradingServicePaperModeTest {

    @Mock private StockService stockService;
    @Mock private PortfolioHoldingRepository portfolioHoldingRepository;
    @Mock private TransactionRepository transactionRepository;
    @Mock private UserRepository userRepository;
    @Mock private PortfolioSnapshotService portfolioSnapshotService;

    @InjectMocks
    private TradingService tradingService;

    private User paperUser;
    private StockQuoteDto appleQuote;

    @BeforeEach
    void setUp() {
        paperUser = TestDataFactory.createUser();
        paperUser.setIsPaperTrading(true);
        paperUser.setPaperBalance(new BigDecimal("100000.00"));
        paperUser.setBalance(new BigDecimal("10000.00")); // real balance should NOT be touched

        appleQuote = TestDataFactory.createStockQuote("AAPL", "Apple Inc.", 180.0);
    }

    @Nested
    @DisplayName("Paper Buy")
    class PaperBuyTests {

        @Test
        @DisplayName("Paper buy deducts from paper balance, not real balance")
        void paperBuy_deductsPaperBalance() {
            when(stockService.getStockQuote("AAPL")).thenReturn(appleQuote);
            when(portfolioHoldingRepository.findByUserAndSymbolAndIsPaper(eq(paperUser), eq("AAPL"), eq(true)))
                    .thenReturn(Optional.empty());
            when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));
            when(portfolioHoldingRepository.save(any(PortfolioHolding.class))).thenAnswer(i -> i.getArgument(0));
            when(transactionRepository.save(any(Transaction.class))).thenAnswer(i -> i.getArgument(0));

            BuyRequest request = new BuyRequest("AAPL", 10);
            TradeResponse response = tradingService.buyStock(paperUser, request);

            assertThat(response.success()).isTrue();
            assertThat(response.message()).contains("Paper Trade");
            // 100000 - (180 * 10) = 98200
            assertThat(paperUser.getPaperBalance()).isEqualByComparingTo(new BigDecimal("98200.00"));
            // Real balance untouched
            assertThat(paperUser.getBalance()).isEqualByComparingTo(new BigDecimal("10000.00"));
        }

        @Test
        @DisplayName("Paper buy creates holding with isPaper=true")
        void paperBuy_createsHoldingWithPaperFlag() {
            when(stockService.getStockQuote("AAPL")).thenReturn(appleQuote);
            when(portfolioHoldingRepository.findByUserAndSymbolAndIsPaper(eq(paperUser), eq("AAPL"), eq(true)))
                    .thenReturn(Optional.empty());
            when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));
            when(portfolioHoldingRepository.save(any(PortfolioHolding.class))).thenAnswer(i -> i.getArgument(0));
            when(transactionRepository.save(any(Transaction.class))).thenAnswer(i -> i.getArgument(0));

            tradingService.buyStock(paperUser, new BuyRequest("AAPL", 5));

            ArgumentCaptor<PortfolioHolding> holdingCaptor = ArgumentCaptor.forClass(PortfolioHolding.class);
            verify(portfolioHoldingRepository).save(holdingCaptor.capture());

            PortfolioHolding savedHolding = holdingCaptor.getValue();
            assertThat(savedHolding.getIsPaper()).isTrue();
            assertThat(savedHolding.getQuantity()).isEqualTo(5);
            assertThat(savedHolding.getSymbol()).isEqualTo("AAPL");
        }

        @Test
        @DisplayName("Paper buy creates transaction with isPaper=true")
        void paperBuy_createsTransactionWithPaperFlag() {
            when(stockService.getStockQuote("AAPL")).thenReturn(appleQuote);
            when(portfolioHoldingRepository.findByUserAndSymbolAndIsPaper(eq(paperUser), eq("AAPL"), eq(true)))
                    .thenReturn(Optional.empty());
            when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));
            when(portfolioHoldingRepository.save(any(PortfolioHolding.class))).thenAnswer(i -> i.getArgument(0));
            when(transactionRepository.save(any(Transaction.class))).thenAnswer(i -> i.getArgument(0));

            tradingService.buyStock(paperUser, new BuyRequest("AAPL", 3));

            ArgumentCaptor<Transaction> txCaptor = ArgumentCaptor.forClass(Transaction.class);
            verify(transactionRepository).save(txCaptor.capture());

            Transaction savedTx = txCaptor.getValue();
            assertThat(savedTx.getIsPaper()).isTrue();
            assertThat(savedTx.getType()).isEqualTo(TransactionType.BUY);
            assertThat(savedTx.getQuantity()).isEqualTo(3);
        }

        @Test
        @DisplayName("Paper buy fails with insufficient paper balance")
        void paperBuy_insufficientPaperBalance() {
            paperUser.setPaperBalance(new BigDecimal("100.00"));

            when(stockService.getStockQuote("AAPL")).thenReturn(appleQuote);

            TradeResponse response = tradingService.buyStock(paperUser, new BuyRequest("AAPL", 10));

            assertThat(response.success()).isFalse();
            assertThat(response.message()).contains("paper");
            verify(portfolioHoldingRepository, never()).save(any());
        }

        @Test
        @DisplayName("Paper buy triggers portfolio snapshot")
        void paperBuy_triggersSnapshot() {
            when(stockService.getStockQuote("AAPL")).thenReturn(appleQuote);
            when(portfolioHoldingRepository.findByUserAndSymbolAndIsPaper(eq(paperUser), eq("AAPL"), eq(true)))
                    .thenReturn(Optional.empty());
            when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));
            when(portfolioHoldingRepository.save(any(PortfolioHolding.class))).thenAnswer(i -> i.getArgument(0));
            when(transactionRepository.save(any(Transaction.class))).thenAnswer(i -> i.getArgument(0));

            tradingService.buyStock(paperUser, new BuyRequest("AAPL", 1));

            verify(portfolioSnapshotService).takeSnapshotForUser(paperUser, true);
        }
    }

    @Nested
    @DisplayName("Paper Sell")
    class PaperSellTests {

        @Test
        @DisplayName("Paper sell adds proceeds to paper balance, not real balance")
        void paperSell_addsToPaperBalance() {
            PortfolioHolding holding = TestDataFactory.createHolding(
                    paperUser, "AAPL", "Apple Inc.", 20, new BigDecimal("150.00"), true);

            when(portfolioHoldingRepository.findByUserAndSymbolAndIsPaper(eq(paperUser), eq("AAPL"), eq(true)))
                    .thenReturn(Optional.of(holding));
            when(stockService.getStockQuote("AAPL")).thenReturn(appleQuote);
            when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));
            when(portfolioHoldingRepository.save(any(PortfolioHolding.class))).thenAnswer(i -> i.getArgument(0));
            when(transactionRepository.save(any(Transaction.class))).thenAnswer(i -> i.getArgument(0));

            TradeResponse response = tradingService.sellStock(paperUser, new SellRequest("AAPL", 10));

            assertThat(response.success()).isTrue();
            assertThat(response.message()).contains("Paper Trade");
            // 100000 + (180 * 10) = 101800
            assertThat(paperUser.getPaperBalance()).isEqualByComparingTo(new BigDecimal("101800.00"));
            assertThat(paperUser.getBalance()).isEqualByComparingTo(new BigDecimal("10000.00"));
        }

        @Test
        @DisplayName("Paper sell fails when no paper holding exists")
        void paperSell_noPaperHolding_fails() {
            when(portfolioHoldingRepository.findByUserAndSymbolAndIsPaper(eq(paperUser), eq("AAPL"), eq(true)))
                    .thenReturn(Optional.empty());

            TradeResponse response = tradingService.sellStock(paperUser, new SellRequest("AAPL", 5));

            assertThat(response.success()).isFalse();
            assertThat(response.message()).contains("paper");
        }

        @Test
        @DisplayName("Paper sell removes holding when all shares sold")
        void paperSell_allShares_removesHolding() {
            PortfolioHolding holding = TestDataFactory.createHolding(
                    paperUser, "AAPL", "Apple Inc.", 5, new BigDecimal("150.00"), true);

            when(portfolioHoldingRepository.findByUserAndSymbolAndIsPaper(eq(paperUser), eq("AAPL"), eq(true)))
                    .thenReturn(Optional.of(holding));
            when(stockService.getStockQuote("AAPL")).thenReturn(appleQuote);
            when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));
            when(transactionRepository.save(any(Transaction.class))).thenAnswer(i -> i.getArgument(0));

            tradingService.sellStock(paperUser, new SellRequest("AAPL", 5));

            verify(portfolioHoldingRepository).delete(holding);
            verify(portfolioHoldingRepository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("Real Trading (non-paper)")
    class RealTradingIsolationTests {

        @Test
        @DisplayName("Real buy deducts from real balance when paper mode is off")
        void realBuy_deductsRealBalance() {
            User realUser = TestDataFactory.createUser();
            realUser.setIsPaperTrading(false);
            realUser.setBalance(new BigDecimal("50000.00"));
            realUser.setPaperBalance(new BigDecimal("100000.00"));

            when(stockService.getStockQuote("AAPL")).thenReturn(appleQuote);
            when(portfolioHoldingRepository.findByUserAndSymbolAndIsPaper(eq(realUser), eq("AAPL"), eq(false)))
                    .thenReturn(Optional.empty());
            when(userRepository.save(any(User.class))).thenAnswer(i -> i.getArgument(0));
            when(portfolioHoldingRepository.save(any(PortfolioHolding.class))).thenAnswer(i -> i.getArgument(0));
            when(transactionRepository.save(any(Transaction.class))).thenAnswer(i -> i.getArgument(0));

            tradingService.buyStock(realUser, new BuyRequest("AAPL", 10));

            // 50000 - (180 * 10) = 48200
            assertThat(realUser.getBalance()).isEqualByComparingTo(new BigDecimal("48200.00"));
            // Paper balance untouched
            assertThat(realUser.getPaperBalance()).isEqualByComparingTo(new BigDecimal("100000.00"));

            ArgumentCaptor<PortfolioHolding> holdingCaptor = ArgumentCaptor.forClass(PortfolioHolding.class);
            verify(portfolioHoldingRepository).save(holdingCaptor.capture());
            assertThat(holdingCaptor.getValue().getIsPaper()).isFalse();
        }
    }
}
