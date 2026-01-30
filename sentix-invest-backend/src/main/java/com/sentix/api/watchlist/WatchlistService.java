package com.sentix.api.watchlist;

import com.sentix.api.stock.StockQuoteDto;
import com.sentix.api.stock.StockService;
import com.sentix.domain.User;
import com.sentix.domain.Watchlist;
import com.sentix.infrastructure.persistence.WatchlistRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class WatchlistService {

    private final WatchlistRepository watchlistRepository;
    private final StockService stockService;

    public List<WatchlistItemResponse> getWatchlist(User user) {
        List<Watchlist> items = watchlistRepository.findByUser(user);
        List<WatchlistItemResponse> responses = new ArrayList<>();

        for (Watchlist item : items) {
            responses.add(buildWatchlistItemResponse(item));
        }

        return responses;
    }

    @Transactional
    public WatchlistItemResponse addToWatchlist(User user, AddToWatchlistRequest request) {
        // Check if already in watchlist
        if (watchlistRepository.existsByUserAndSymbol(user, request.symbol().toUpperCase())) {
            log.info("Stock {} already in watchlist for user {}", request.symbol(), user.getEmail());
            return watchlistRepository.findByUserAndSymbol(user, request.symbol().toUpperCase())
                    .map(this::buildWatchlistItemResponse)
                    .orElse(null);
        }

        Watchlist watchlistItem = Watchlist.builder()
                .user(user)
                .symbol(request.symbol().toUpperCase())
                .stockName(request.stockName())
                .build();

        watchlistItem = watchlistRepository.save(watchlistItem);
        log.info("Added {} to watchlist for user {}", request.symbol(), user.getEmail());

        return buildWatchlistItemResponse(watchlistItem);
    }

    @Transactional
    public boolean removeFromWatchlist(User user, String symbol) {
        if (!watchlistRepository.existsByUserAndSymbol(user, symbol.toUpperCase())) {
            return false;
        }
        watchlistRepository.deleteByUserAndSymbol(user, symbol.toUpperCase());
        log.info("Removed {} from watchlist for user {}", symbol, user.getEmail());
        return true;
    }

    public boolean isInWatchlist(User user, String symbol) {
        return watchlistRepository.existsByUserAndSymbol(user, symbol.toUpperCase());
    }

    private WatchlistItemResponse buildWatchlistItemResponse(Watchlist item) {
        Double currentPrice = null;
        Double change = null;
        Double changePercent = null;
        String currency = null;

        try {
            StockQuoteDto quote = stockService.getStockQuote(item.getSymbol());
            if (quote != null) {
                currentPrice = quote.getPrice();
                change = quote.getChange();
                changePercent = quote.getChangePercent();
                currency = quote.getCurrency();
            }
        } catch (Exception e) {
            log.warn("Could not fetch price for watchlist item {}: {}", item.getSymbol(), e.getMessage());
        }

        return WatchlistItemResponse.builder()
                .id(item.getId())
                .symbol(item.getSymbol())
                .stockName(item.getStockName())
                .addedAt(item.getAddedAt())
                .currentPrice(currentPrice)
                .change(change)
                .changePercent(changePercent)
                .currency(currency)
                .build();
    }
}
