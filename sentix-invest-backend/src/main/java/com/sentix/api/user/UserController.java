package com.sentix.api.user;

import com.sentix.domain.User;
import com.sentix.infrastructure.persistence.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;

    @GetMapping("/me")
    public ResponseEntity<UserResponse> getCurrentUser(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(UserResponse.builder()
                .fullName(user.getFullName())
                .email(user.getEmail())
                .balance(user.getBalance())
                .paperBalance(user.getPaperBalance())
                .isPaperTrading(user.getIsPaperTrading())
                .preferredCurrency(user.getPreferredCurrency())
                .build());
    }

    @PostMapping("/fcm-token")
    public ResponseEntity<Void> updateFcmToken(
            @AuthenticationPrincipal User user,
            @RequestBody FcmTokenRequest request) {
        user.setFcmToken(request.getFcmToken());
        userRepository.save(user);
        return ResponseEntity.ok().build();
    }

    @PatchMapping("/paper-trading")
    public ResponseEntity<Map<String, Object>> togglePaperTrading(@AuthenticationPrincipal User user) {
        user.setIsPaperTrading(!Boolean.TRUE.equals(user.getIsPaperTrading()));
        userRepository.save(user);
        return ResponseEntity.ok(Map.of(
                "isPaperTrading", user.getIsPaperTrading(),
                "paperBalance", user.getPaperBalance(),
                "balance", user.getBalance()));
    }

    @PatchMapping("/preferred-currency")
    public ResponseEntity<Map<String, Object>> updatePreferredCurrency(
            @AuthenticationPrincipal User user,
            @RequestBody Map<String, String> request) {
        String currency = request.get("currency");
        if (currency == null || currency.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Currency is required"));
        }
        user.setPreferredCurrency(currency.toUpperCase());
        userRepository.save(user);
        return ResponseEntity.ok(Map.of("preferredCurrency", user.getPreferredCurrency()));
    }
}
