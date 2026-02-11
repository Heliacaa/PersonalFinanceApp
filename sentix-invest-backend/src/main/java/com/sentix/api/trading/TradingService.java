package com.sentix.api.trading;

import com.sentix.api.common.PageResponse;
import com.sentix.api.portfolio.PortfolioSnapshotService;
import com.sentix.api.stock.StockQuoteDto;
import com.sentix.api.stock.StockService;
import com.sentix.domain.*;
import com.sentix.infrastructure.persistence.PortfolioHoldingRepository;
import com.sentix.infrastructure.persistence.TransactionRepository;
import com.sentix.infrastructure.persistence.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class TradingService {

    private final StockService stockService;
    private final PortfolioHoldingRepository portfolioHoldingRepository;
    private final TransactionRepository transactionRepository;
    private final UserRepository userRepository;
    private final PortfolioSnapshotService portfolioSnapshotService;

    @Transactional
    public TradeResponse buyStock(User user, BuyRequest request) {
        boolean isPaper = Boolean.TRUE.equals(user.getIsPaperTrading());
        log.info("User {} attempting to buy {} shares of {} (paper={})", user.getEmail(), request.quantity(), request.symbol(), isPaper);

        // 1. Fetch current stock price
        StockQuoteDto stockQuote = stockService.getStockQuote(request.symbol());
        if (stockQuote == null) {
            return TradeResponse.builder()
                    .success(false)
                    .message("Could not fetch stock price for " + request.symbol())
                    .build();
        }

        // 2. Calculate total cost
        BigDecimal pricePerShare = BigDecimal.valueOf(stockQuote.getPrice());
        BigDecimal totalCost = pricePerShare.multiply(BigDecimal.valueOf(request.quantity()));

        // 3. Check if user has sufficient balance (paper or real)
        BigDecimal availableBalance = isPaper ? user.getPaperBalance() : user.getBalance();
        if (availableBalance.compareTo(totalCost) < 0) {
            return TradeResponse.builder()
                    .success(false)
                    .message("Insufficient " + (isPaper ? "paper " : "") + "balance. Required: " + totalCost + " " + stockQuote.getCurrency() +
                            ", Available: " + availableBalance)
                    .build();
        }

        // 4. Deduct from user balance
        if (isPaper) {
            user.setPaperBalance(user.getPaperBalance().subtract(totalCost));
        } else {
            user.setBalance(user.getBalance().subtract(totalCost));
        }
        userRepository.save(user);

        // 5. Create or update portfolio holding (scoped by paper flag)
        PortfolioHolding holding = portfolioHoldingRepository
                .findByUserAndSymbolAndIsPaper(user, request.symbol().toUpperCase(), isPaper)
                .orElse(null);

        if (holding == null) {
            // Create new holding
            holding = PortfolioHolding.builder()
                    .user(user)
                    .symbol(request.symbol().toUpperCase())
                    .stockName(stockQuote.getName())
                    .quantity(request.quantity())
                    .averagePurchasePrice(pricePerShare)
                    .currency(stockQuote.getCurrency())
                    .isPaper(isPaper)
                    .build();
        } else {
            // Update existing holding with new average price
            BigDecimal existingTotal = holding.getAveragePurchasePrice()
                    .multiply(BigDecimal.valueOf(holding.getQuantity()));
            int newTotalQuantity = holding.getQuantity() + request.quantity();
            BigDecimal newAveragePrice = existingTotal.add(totalCost)
                    .divide(BigDecimal.valueOf(newTotalQuantity), 4, RoundingMode.HALF_UP);

            holding.setQuantity(newTotalQuantity);
            holding.setAveragePurchasePrice(newAveragePrice);
        }
        portfolioHoldingRepository.save(holding);

        // 6. Create transaction record
        Transaction transaction = Transaction.builder()
                .user(user)
                .symbol(request.symbol().toUpperCase())
                .stockName(stockQuote.getName())
                .type(TransactionType.BUY)
                .quantity(request.quantity())
                .pricePerShare(pricePerShare)
                .totalAmount(totalCost)
                .currency(stockQuote.getCurrency())
                .executedAt(LocalDateTime.now())
                .isPaper(isPaper)
                .build();
        transactionRepository.save(transaction);

        log.info("User {} successfully bought {} shares of {} for {} (paper={})",
                user.getEmail(), request.quantity(), request.symbol(), totalCost, isPaper);

        // Take portfolio snapshot after trade
        try {
            portfolioSnapshotService.takeSnapshotForUser(user, isPaper);
        } catch (Exception e) {
            log.warn("Failed to take post-trade snapshot: {}", e.getMessage());
        }

        return TradeResponse.builder()
                .success(true)
                .message("Successfully purchased " + request.quantity() + " shares of " + stockQuote.getName() + (isPaper ? " (Paper Trade)" : ""))
                .transaction(mapToTransactionResponse(transaction))
                .newBalance(isPaper ? user.getPaperBalance() : user.getBalance())
                .build();
    }

    @Transactional
    public TradeResponse sellStock(User user, SellRequest request) {
        boolean isPaper = Boolean.TRUE.equals(user.getIsPaperTrading());
        log.info("User {} attempting to sell {} shares of {} (paper={})", user.getEmail(), request.quantity(), request.symbol(), isPaper);

        // 1. Check if user owns the stock (scoped by paper flag)
        PortfolioHolding holding = portfolioHoldingRepository
                .findByUserAndSymbolAndIsPaper(user, request.symbol().toUpperCase(), isPaper)
                .orElse(null);

        if (holding == null) {
            return TradeResponse.builder()
                    .success(false)
                    .message("You don't own any " + (isPaper ? "paper " : "") + "shares of " + request.symbol())
                    .build();
        }

        // 2. Check if user has enough shares
        if (holding.getQuantity() < request.quantity()) {
            return TradeResponse.builder()
                    .success(false)
                    .message("Insufficient shares. You own " + holding.getQuantity() +
                            " shares but trying to sell " + request.quantity())
                    .build();
        }

        // 3. Fetch current stock price
        StockQuoteDto stockQuote = stockService.getStockQuote(request.symbol());
        if (stockQuote == null) {
            return TradeResponse.builder()
                    .success(false)
                    .message("Could not fetch stock price for " + request.symbol())
                    .build();
        }

        // 4. Calculate proceeds
        BigDecimal pricePerShare = BigDecimal.valueOf(stockQuote.getPrice());
        BigDecimal totalProceeds = pricePerShare.multiply(BigDecimal.valueOf(request.quantity()));

        // 5. Add to user balance (paper or real)
        if (isPaper) {
            user.setPaperBalance(user.getPaperBalance().add(totalProceeds));
        } else {
            user.setBalance(user.getBalance().add(totalProceeds));
        }
        userRepository.save(user);

        // 6. Update or remove portfolio holding
        int remainingQuantity = holding.getQuantity() - request.quantity();
        if (remainingQuantity == 0) {
            portfolioHoldingRepository.delete(holding);
        } else {
            holding.setQuantity(remainingQuantity);
            portfolioHoldingRepository.save(holding);
        }

        // 7. Create transaction record
        Transaction transaction = Transaction.builder()
                .user(user)
                .symbol(request.symbol().toUpperCase())
                .stockName(stockQuote.getName())
                .type(TransactionType.SELL)
                .quantity(request.quantity())
                .pricePerShare(pricePerShare)
                .totalAmount(totalProceeds)
                .currency(stockQuote.getCurrency())
                .executedAt(LocalDateTime.now())
                .isPaper(isPaper)
                .build();
        transactionRepository.save(transaction);

        log.info("User {} successfully sold {} shares of {} for {} (paper={})",
                user.getEmail(), request.quantity(), request.symbol(), totalProceeds, isPaper);

        // Take portfolio snapshot after trade
        try {
            portfolioSnapshotService.takeSnapshotForUser(user, isPaper);
        } catch (Exception e) {
            log.warn("Failed to take post-trade snapshot: {}", e.getMessage());
        }

        return TradeResponse.builder()
                .success(true)
                .message("Successfully sold " + request.quantity() + " shares of " + stockQuote.getName() + (isPaper ? " (Paper Trade)" : ""))
                .transaction(mapToTransactionResponse(transaction))
                .newBalance(isPaper ? user.getPaperBalance() : user.getBalance())
                .build();
    }

    public List<TransactionResponse> getTransactions(User user) {
        return transactionRepository.findByUserOrderByExecutedAtDesc(user)
                .stream()
                .map(this::mapToTransactionResponse)
                .toList();
    }

    public List<TransactionResponse> getTransactionsBySymbol(User user, String symbol) {
        return transactionRepository.findByUserAndSymbolOrderByExecutedAtDesc(user, symbol.toUpperCase())
                .stream()
                .map(this::mapToTransactionResponse)
                .toList();
    }

    public PageResponse<TransactionResponse> getTransactionsPaginated(User user, Pageable pageable) {
        Page<Transaction> page = transactionRepository.findByUserOrderByExecutedAtDesc(user, pageable);
        List<TransactionResponse> content = page.getContent().stream()
                .map(this::mapToTransactionResponse)
                .toList();
        return PageResponse.from(page, content);
    }

    private TransactionResponse mapToTransactionResponse(Transaction transaction) {
        return TransactionResponse.builder()
                .id(transaction.getId())
                .symbol(transaction.getSymbol())
                .stockName(transaction.getStockName())
                .type(transaction.getType().name())
                .quantity(transaction.getQuantity())
                .pricePerShare(transaction.getPricePerShare())
                .totalAmount(transaction.getTotalAmount())
                .currency(transaction.getCurrency())
                .executedAt(transaction.getExecutedAt())
                .build();
    }
}
