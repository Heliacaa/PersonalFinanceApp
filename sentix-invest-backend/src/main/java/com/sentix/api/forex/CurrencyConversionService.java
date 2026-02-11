package com.sentix.api.forex;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Currency conversion service with short-lived caching.
 * Wraps ForexService to provide BigDecimal-based conversion with a 5-minute TTL cache.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CurrencyConversionService {

    private final ForexService forexService;

    // Cache: key = "FROM:TO", value = CachedRate
    private final Map<String, CachedRate> rateCache = new ConcurrentHashMap<>();
    private static final long CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

    /**
     * Convert an amount from one currency to another.
     */
    public BigDecimal convert(BigDecimal amount, String fromCurrency, String toCurrency) {
        if (fromCurrency.equalsIgnoreCase(toCurrency)) {
            return amount;
        }

        BigDecimal rate = getRate(fromCurrency, toCurrency);
        if (rate == null) {
            log.warn("Could not get exchange rate from {} to {}, returning original amount", fromCurrency, toCurrency);
            return amount;
        }

        return amount.multiply(rate).setScale(4, RoundingMode.HALF_UP);
    }

    /**
     * Get exchange rate between two currencies, with caching.
     */
    public BigDecimal getRate(String fromCurrency, String toCurrency) {
        if (fromCurrency.equalsIgnoreCase(toCurrency)) {
            return BigDecimal.ONE;
        }

        String cacheKey = fromCurrency.toUpperCase() + ":" + toCurrency.toUpperCase();
        CachedRate cached = rateCache.get(cacheKey);

        if (cached != null && !cached.isExpired()) {
            return cached.rate;
        }

        try {
            Map<String, Object> result = forexService.convertCurrency(
                    fromCurrency.toUpperCase(),
                    toCurrency.toUpperCase(),
                    1.0);

            if (result != null && result.containsKey("rate")) {
                Object rateObj = result.get("rate");
                BigDecimal rate;
                if (rateObj instanceof Number) {
                    rate = BigDecimal.valueOf(((Number) rateObj).doubleValue());
                } else {
                    rate = new BigDecimal(rateObj.toString());
                }

                rateCache.put(cacheKey, new CachedRate(rate));
                return rate;
            }
        } catch (Exception e) {
            log.warn("Error fetching exchange rate from {} to {}: {}", fromCurrency, toCurrency, e.getMessage());
        }

        // Try reverse lookup
        String reverseKey = toCurrency.toUpperCase() + ":" + fromCurrency.toUpperCase();
        CachedRate reverseCached = rateCache.get(reverseKey);
        if (reverseCached != null && !reverseCached.isExpired()) {
            return BigDecimal.ONE.divide(reverseCached.rate, 6, RoundingMode.HALF_UP);
        }

        return null;
    }

    private static class CachedRate {
        final BigDecimal rate;
        final long timestamp;

        CachedRate(BigDecimal rate) {
            this.rate = rate;
            this.timestamp = System.currentTimeMillis();
        }

        boolean isExpired() {
            return System.currentTimeMillis() - timestamp > CACHE_TTL_MS;
        }
    }
}
