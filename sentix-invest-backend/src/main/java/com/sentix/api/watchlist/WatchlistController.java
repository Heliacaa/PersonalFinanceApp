package com.sentix.api.watchlist;

import com.sentix.api.common.PageResponse;
import com.sentix.domain.User;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/watchlist")
@RequiredArgsConstructor
public class WatchlistController {

    private final WatchlistService watchlistService;

    @GetMapping
    public ResponseEntity<PageResponse<WatchlistItemResponse>> getWatchlist(
            @AuthenticationPrincipal User user,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(watchlistService.getWatchlistPaginated(user, PageRequest.of(page, size)));
    }

    @PostMapping
    public ResponseEntity<WatchlistItemResponse> addToWatchlist(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody AddToWatchlistRequest request) {
        WatchlistItemResponse response = watchlistService.addToWatchlist(user, request);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{symbol}")
    public ResponseEntity<Map<String, Object>> removeFromWatchlist(
            @AuthenticationPrincipal User user,
            @PathVariable String symbol) {
        boolean removed = watchlistService.removeFromWatchlist(user, symbol);
        if (removed) {
            return ResponseEntity.ok(Map.of("success", true, "message", "Removed from watchlist"));
        }
        return ResponseEntity.notFound().build();
    }

    @GetMapping("/{symbol}/exists")
    public ResponseEntity<Map<String, Boolean>> isInWatchlist(
            @AuthenticationPrincipal User user,
            @PathVariable String symbol) {
        boolean exists = watchlistService.isInWatchlist(user, symbol);
        return ResponseEntity.ok(Map.of("exists", exists));
    }
}
