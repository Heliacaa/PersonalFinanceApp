package com.sentix.test;

import com.sentix.domain.*;
import com.sentix.api.stock.StockQuoteDto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Factory for creating test data objects.
 */
public class TestDataFactory {

    public static User createUser() {
        return createUser("test@example.com", "Test User");
    }

    public static User createUser(String email, String fullName) {
        User user = User.builder()
                .id(UUID.randomUUID())
                .email(email)
                .passwordHash("$2a$10$hashedPasswordValue")
                .fullName(fullName)
                .role(Role.USER)
                .balance(new BigDecimal("10000.00"))
                .paperBalance(new BigDecimal("100000.00"))
                .isPaperTrading(false)
                .preferredCurrency("USD")
                .build();
        user.setCreatedAt(LocalDateTime.now());
        user.setUpdatedAt(LocalDateTime.now());
        return user;
    }

    public static PortfolioHolding createHolding(User user, String symbol, String name,
                                                   int quantity, BigDecimal avgPrice) {
        return createHolding(user, symbol, name, quantity, avgPrice, false);
    }

    public static PortfolioHolding createHolding(User user, String symbol, String name,
                                                   int quantity, BigDecimal avgPrice, boolean isPaper) {
        PortfolioHolding holding = PortfolioHolding.builder()
                .id(UUID.randomUUID())
                .user(user)
                .symbol(symbol)
                .stockName(name)
                .quantity(quantity)
                .averagePurchasePrice(avgPrice)
                .currency("USD")
                .isPaper(isPaper)
                .build();
        holding.setCreatedAt(LocalDateTime.now());
        holding.setUpdatedAt(LocalDateTime.now());
        return holding;
    }

    public static Transaction createTransaction(User user, String symbol, String name,
                                                  TransactionType type, int quantity,
                                                  BigDecimal price) {
        return createTransaction(user, symbol, name, type, quantity, price, false);
    }

    public static Transaction createTransaction(User user, String symbol, String name,
                                                  TransactionType type, int quantity,
                                                  BigDecimal price, boolean isPaper) {
        return Transaction.builder()
                .id(UUID.randomUUID())
                .user(user)
                .symbol(symbol)
                .stockName(name)
                .type(type)
                .quantity(quantity)
                .pricePerShare(price)
                .totalAmount(price.multiply(BigDecimal.valueOf(quantity)))
                .currency("USD")
                .executedAt(LocalDateTime.now())
                .isPaper(isPaper)
                .build();
    }

    public static PriceAlert createPriceAlert(User user, String symbol, String name,
                                                AlertType alertType, BigDecimal targetPrice) {
        PriceAlert alert = PriceAlert.builder()
                .id(UUID.randomUUID())
                .user(user)
                .symbol(symbol)
                .stockName(name)
                .alertType(alertType)
                .targetPrice(targetPrice)
                .isActive(true)
                .build();
        alert.setCreatedAt(LocalDateTime.now());
        return alert;
    }

    public static StockQuoteDto createStockQuote(String symbol, String name, double price) {
        return StockQuoteDto.builder()
                .symbol(symbol)
                .name(name)
                .price(price)
                .change(1.5)
                .changePercent(0.85)
                .currency("USD")
                .marketState("REGULAR")
                .timestamp(LocalDateTime.now().toString())
                .build();
    }
}
