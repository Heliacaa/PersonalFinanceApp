package com.sentix.api.forex;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CurrencyConversionServiceTest {

    @Mock
    private ForexService forexService;

    @InjectMocks
    private CurrencyConversionService conversionService;

    @Test
    @DisplayName("convert returns same amount when currencies are equal")
    void convert_sameCurrency_returnsSameAmount() {
        BigDecimal amount = new BigDecimal("100.00");

        BigDecimal result = conversionService.convert(amount, "USD", "USD");

        assertThat(result).isEqualByComparingTo(amount);
        verifyNoInteractions(forexService);
    }

    @Test
    @DisplayName("convert applies exchange rate correctly")
    void convert_differentCurrencies_appliesRate() {
        when(forexService.convertCurrency("USD", "EUR", 1.0))
                .thenReturn(Map.of("rate", 0.92));

        BigDecimal result = conversionService.convert(new BigDecimal("100.00"), "USD", "EUR");

        assertThat(result).isEqualByComparingTo(new BigDecimal("92.0000"));
    }

    @Test
    @DisplayName("getRate returns ONE for same currency")
    void getRate_sameCurrency_returnsOne() {
        BigDecimal rate = conversionService.getRate("USD", "USD");

        assertThat(rate).isEqualByComparingTo(BigDecimal.ONE);
        verifyNoInteractions(forexService);
    }

    @Test
    @DisplayName("getRate caches results for subsequent calls")
    void getRate_cachesResults() {
        when(forexService.convertCurrency("USD", "EUR", 1.0))
                .thenReturn(Map.of("rate", 0.92));

        // First call - fetches from forex service
        BigDecimal rate1 = conversionService.getRate("USD", "EUR");
        // Second call - should use cache
        BigDecimal rate2 = conversionService.getRate("USD", "EUR");

        assertThat(rate1).isEqualByComparingTo(rate2);
        // ForexService should only be called once (cached on second call)
        verify(forexService, times(1)).convertCurrency("USD", "EUR", 1.0);
    }

    @Test
    @DisplayName("convert returns original amount when rate lookup fails")
    void convert_rateLookupFails_returnsOriginalAmount() {
        when(forexService.convertCurrency(anyString(), anyString(), anyDouble()))
                .thenThrow(new RuntimeException("Service unavailable"));

        BigDecimal amount = new BigDecimal("100.00");
        BigDecimal result = conversionService.convert(amount, "USD", "JPY");

        assertThat(result).isEqualByComparingTo(amount);
    }

    @Test
    @DisplayName("getRate returns null when forex service returns no rate")
    void getRate_noRateInResponse_returnsNull() {
        when(forexService.convertCurrency("USD", "GBP", 1.0))
                .thenReturn(Map.of("status", "error"));

        BigDecimal rate = conversionService.getRate("USD", "GBP");

        assertThat(rate).isNull();
    }

    @Test
    @DisplayName("getRate handles Number and String rate values")
    void getRate_handlesVariousRateTypes() {
        // Test with Number (Double)
        when(forexService.convertCurrency("USD", "EUR", 1.0))
                .thenReturn(Map.of("rate", 0.92));

        BigDecimal rate = conversionService.getRate("USD", "EUR");
        assertThat(rate).isEqualByComparingTo(new BigDecimal("0.92"));
    }

    @Test
    @DisplayName("convert handles case-insensitive currency codes")
    void convert_caseInsensitiveCurrencyCodes() {
        BigDecimal result = conversionService.convert(new BigDecimal("100"), "usd", "USD");
        assertThat(result).isEqualByComparingTo(new BigDecimal("100"));
    }
}
