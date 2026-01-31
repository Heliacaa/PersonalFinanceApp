package com.sentix.api.alert;

import com.sentix.domain.User;
import com.sentix.infrastructure.persistence.UserRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/alerts")
@RequiredArgsConstructor
public class PriceAlertController {

    private final PriceAlertService priceAlertService;
    private final UserRepository userRepository;

    @PostMapping
    public ResponseEntity<PriceAlertResponse> createAlert(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody CreateAlertRequest request) {
        User user = getUser(userDetails);
        PriceAlertResponse response = priceAlertService.createAlert(user, request);
        return ResponseEntity.ok(response);
    }

    @GetMapping
    public ResponseEntity<List<PriceAlertResponse>> getUserAlerts(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        List<PriceAlertResponse> alerts = priceAlertService.getUserAlerts(user);
        return ResponseEntity.ok(alerts);
    }

    @GetMapping("/active")
    public ResponseEntity<List<PriceAlertResponse>> getActiveAlerts(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        List<PriceAlertResponse> alerts = priceAlertService.getActiveAlerts(user);
        return ResponseEntity.ok(alerts);
    }

    @GetMapping("/symbol/{symbol}")
    public ResponseEntity<List<PriceAlertResponse>> getAlertsBySymbol(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable String symbol) {
        User user = getUser(userDetails);
        List<PriceAlertResponse> alerts = priceAlertService.getAlertsBySymbol(user, symbol);
        return ResponseEntity.ok(alerts);
    }

    @DeleteMapping("/{alertId}")
    public ResponseEntity<Void> deleteAlert(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID alertId) {
        User user = getUser(userDetails);
        priceAlertService.deleteAlert(user, alertId);
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{alertId}/toggle")
    public ResponseEntity<PriceAlertResponse> toggleAlert(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID alertId) {
        User user = getUser(userDetails);
        PriceAlertResponse response = priceAlertService.toggleAlert(user, alertId);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/check")
    public ResponseEntity<List<PriceAlertResponse>> checkTriggeredAlerts() {
        // This endpoint can be called by a scheduler or admin
        List<PriceAlertResponse> triggered = priceAlertService.checkAndTriggerAlerts();
        return ResponseEntity.ok(triggered);
    }

    private User getUser(UserDetails userDetails) {
        return userRepository.findByEmail(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
    }
}
