package com.sentix.api.alert;

import com.sentix.api.stock.StockQuoteDto;
import com.sentix.api.stock.StockService;
import com.sentix.domain.AlertType;
import com.sentix.domain.PriceAlert;
import com.sentix.domain.User;
import com.sentix.infrastructure.persistence.PriceAlertRepository;
import com.sentix.service.PushNotificationService;
import com.sentix.test.TestDataFactory;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PriceAlertServiceTest {

    @Mock
    private PriceAlertRepository priceAlertRepository;

    @Mock
    private StockService stockService;

    @Mock
    private PushNotificationService pushNotificationService;

    @InjectMocks
    private PriceAlertService priceAlertService;

    private User testUser;

    @BeforeEach
    void setUp() {
        testUser = TestDataFactory.createUser();
        testUser.setFcmToken("test-fcm-token");
    }

    @Test
    @DisplayName("ABOVE alert triggers when current price >= target price")
    void checkAndTriggerAlerts_aboveAlert_triggersWhenPriceAbove() {
        PriceAlert alert = TestDataFactory.createPriceAlert(
                testUser, "AAPL", "Apple Inc.", AlertType.ABOVE, new BigDecimal("180.00"));

        StockQuoteDto quote = TestDataFactory.createStockQuote("AAPL", "Apple Inc.", 185.0);

        when(priceAlertRepository.findByIsActiveTrue()).thenReturn(List.of(alert));
        when(stockService.getStockQuote("AAPL")).thenReturn(quote);
        when(priceAlertRepository.save(any(PriceAlert.class))).thenAnswer(i -> i.getArgument(0));

        List<PriceAlertResponse> triggered = priceAlertService.checkAndTriggerAlerts();

        assertThat(triggered).hasSize(1);
        assertThat(alert.getIsActive()).isFalse();
        assertThat(alert.getTriggeredAt()).isNotNull();
        verify(priceAlertRepository).save(alert);
    }

    @Test
    @DisplayName("ABOVE alert does NOT trigger when current price < target price")
    void checkAndTriggerAlerts_aboveAlert_doesNotTriggerWhenPriceBelow() {
        PriceAlert alert = TestDataFactory.createPriceAlert(
                testUser, "AAPL", "Apple Inc.", AlertType.ABOVE, new BigDecimal("200.00"));

        StockQuoteDto quote = TestDataFactory.createStockQuote("AAPL", "Apple Inc.", 185.0);

        when(priceAlertRepository.findByIsActiveTrue()).thenReturn(List.of(alert));
        when(stockService.getStockQuote("AAPL")).thenReturn(quote);

        List<PriceAlertResponse> triggered = priceAlertService.checkAndTriggerAlerts();

        assertThat(triggered).isEmpty();
        assertThat(alert.getIsActive()).isTrue();
    }

    @Test
    @DisplayName("BELOW alert triggers when current price <= target price")
    void checkAndTriggerAlerts_belowAlert_triggersWhenPriceBelow() {
        PriceAlert alert = TestDataFactory.createPriceAlert(
                testUser, "TSLA", "Tesla Inc.", AlertType.BELOW, new BigDecimal("200.00"));

        StockQuoteDto quote = TestDataFactory.createStockQuote("TSLA", "Tesla Inc.", 195.0);

        when(priceAlertRepository.findByIsActiveTrue()).thenReturn(List.of(alert));
        when(stockService.getStockQuote("TSLA")).thenReturn(quote);
        when(priceAlertRepository.save(any(PriceAlert.class))).thenAnswer(i -> i.getArgument(0));

        List<PriceAlertResponse> triggered = priceAlertService.checkAndTriggerAlerts();

        assertThat(triggered).hasSize(1);
        assertThat(alert.getIsActive()).isFalse();
    }

    @Test
    @DisplayName("PERCENT_CHANGE alert triggers when percentage change exceeds threshold")
    void checkAndTriggerAlerts_percentChange_triggersWhenExceedsThreshold() {
        PriceAlert alert = TestDataFactory.createPriceAlert(
                testUser, "GOOGL", "Alphabet Inc.", AlertType.PERCENT_CHANGE, new BigDecimal("5.00"));
        alert.setReferencePrice(new BigDecimal("100.00")); // Reference price

        StockQuoteDto quote = TestDataFactory.createStockQuote("GOOGL", "Alphabet Inc.", 106.0);

        when(priceAlertRepository.findByIsActiveTrue()).thenReturn(List.of(alert));
        when(stockService.getStockQuote("GOOGL")).thenReturn(quote);
        when(priceAlertRepository.save(any(PriceAlert.class))).thenAnswer(i -> i.getArgument(0));

        List<PriceAlertResponse> triggered = priceAlertService.checkAndTriggerAlerts();

        assertThat(triggered).hasSize(1);
        assertThat(alert.getIsActive()).isFalse();
    }

    @Test
    @DisplayName("PERCENT_CHANGE alert does NOT trigger when below threshold")
    void checkAndTriggerAlerts_percentChange_doesNotTriggerBelowThreshold() {
        PriceAlert alert = TestDataFactory.createPriceAlert(
                testUser, "GOOGL", "Alphabet Inc.", AlertType.PERCENT_CHANGE, new BigDecimal("10.00"));
        alert.setReferencePrice(new BigDecimal("100.00"));

        StockQuoteDto quote = TestDataFactory.createStockQuote("GOOGL", "Alphabet Inc.", 106.0);

        when(priceAlertRepository.findByIsActiveTrue()).thenReturn(List.of(alert));
        when(stockService.getStockQuote("GOOGL")).thenReturn(quote);

        List<PriceAlertResponse> triggered = priceAlertService.checkAndTriggerAlerts();

        assertThat(triggered).isEmpty();
        assertThat(alert.getIsActive()).isTrue();
    }

    @Test
    @DisplayName("EARNINGS_REMINDER alert triggers when earnings date is within daysNotice")
    void checkAndTriggerAlerts_earningsReminder_triggersWhenWithinDays() {
        PriceAlert alert = TestDataFactory.createPriceAlert(
                testUser, "MSFT", "Microsoft Corp.", AlertType.EARNINGS_REMINDER, BigDecimal.ZERO);
        alert.setDaysNotice(7);

        // Earnings date is 3 days from now (within 7-day notice)
        String earningsDate = java.time.LocalDate.now().plusDays(3).toString();

        when(priceAlertRepository.findByIsActiveTrue()).thenReturn(List.of(alert));
        when(stockService.getEarnings("MSFT")).thenReturn(Map.of("nextEarningsDate", earningsDate));
        when(priceAlertRepository.save(any(PriceAlert.class))).thenAnswer(i -> i.getArgument(0));

        List<PriceAlertResponse> triggered = priceAlertService.checkAndTriggerAlerts();

        assertThat(triggered).hasSize(1);
        assertThat(alert.getIsActive()).isFalse();
    }

    @Test
    @DisplayName("DIVIDEND_PAYMENT alert triggers when payment date is within daysNotice")
    void checkAndTriggerAlerts_dividendPayment_triggersWhenWithinDays() {
        PriceAlert alert = TestDataFactory.createPriceAlert(
                testUser, "JNJ", "Johnson & Johnson", AlertType.DIVIDEND_PAYMENT, BigDecimal.ZERO);
        alert.setDaysNotice(5);

        String paymentDate = java.time.LocalDate.now().plusDays(2).toString();

        when(priceAlertRepository.findByIsActiveTrue()).thenReturn(List.of(alert));
        when(stockService.getDividends("JNJ")).thenReturn(
                Map.of("nextDividend", Map.of("paymentDate", paymentDate, "amount", 1.13)));
        when(priceAlertRepository.save(any(PriceAlert.class))).thenAnswer(i -> i.getArgument(0));

        List<PriceAlertResponse> triggered = priceAlertService.checkAndTriggerAlerts();

        assertThat(triggered).hasSize(1);
        assertThat(alert.getIsActive()).isFalse();
    }

    @Test
    @DisplayName("Push notification is sent when alert is triggered")
    void checkAndTriggerAlerts_sendsPushNotification() {
        PriceAlert alert = TestDataFactory.createPriceAlert(
                testUser, "AAPL", "Apple Inc.", AlertType.ABOVE, new BigDecimal("180.00"));

        StockQuoteDto quote = TestDataFactory.createStockQuote("AAPL", "Apple Inc.", 185.0);

        when(priceAlertRepository.findByIsActiveTrue()).thenReturn(List.of(alert));
        when(stockService.getStockQuote("AAPL")).thenReturn(quote);
        when(priceAlertRepository.save(any(PriceAlert.class))).thenAnswer(i -> i.getArgument(0));

        priceAlertService.checkAndTriggerAlerts();

        verify(pushNotificationService).sendPriceAlertNotification(
                eq("test-fcm-token"), eq("AAPL"), eq("Apple Inc."),
                eq(180.00), eq(185.0), eq("ABOVE"));
    }

    @Test
    @DisplayName("Multiple alerts can be triggered in one check cycle")
    void checkAndTriggerAlerts_multipleAlerts() {
        PriceAlert alert1 = TestDataFactory.createPriceAlert(
                testUser, "AAPL", "Apple Inc.", AlertType.ABOVE, new BigDecimal("180.00"));
        PriceAlert alert2 = TestDataFactory.createPriceAlert(
                testUser, "TSLA", "Tesla Inc.", AlertType.BELOW, new BigDecimal("200.00"));

        when(priceAlertRepository.findByIsActiveTrue()).thenReturn(List.of(alert1, alert2));
        when(stockService.getStockQuote("AAPL")).thenReturn(
                TestDataFactory.createStockQuote("AAPL", "Apple Inc.", 185.0));
        when(stockService.getStockQuote("TSLA")).thenReturn(
                TestDataFactory.createStockQuote("TSLA", "Tesla Inc.", 195.0));
        when(priceAlertRepository.save(any(PriceAlert.class))).thenAnswer(i -> i.getArgument(0));

        List<PriceAlertResponse> triggered = priceAlertService.checkAndTriggerAlerts();

        assertThat(triggered).hasSize(2);
    }

    @Test
    @DisplayName("Create alert returns valid response")
    void createAlert_validRequest_returnsResponse() {
        CreateAlertRequest request = new CreateAlertRequest();
        request.setSymbol("AAPL");
        request.setStockName("Apple Inc.");
        request.setTargetPrice(new BigDecimal("200.00"));
        request.setAlertType("ABOVE");

        when(priceAlertRepository.save(any(PriceAlert.class))).thenAnswer(i -> {
            PriceAlert saved = i.getArgument(0);
            saved.setId(java.util.UUID.randomUUID());
            saved.setCreatedAt(java.time.LocalDateTime.now());
            return saved;
        });
        when(stockService.getStockQuote(anyString())).thenReturn(
                TestDataFactory.createStockQuote("AAPL", "Apple Inc.", 185.0));

        PriceAlertResponse response = priceAlertService.createAlert(testUser, request);

        assertThat(response).isNotNull();
        assertThat(response.getSymbol()).isEqualTo("AAPL");
        assertThat(response.getAlertType()).isEqualTo("ABOVE");
        assertThat(response.getIsActive()).isTrue();
    }
}
