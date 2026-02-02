package com.sentix.api.user;

import com.sentix.domain.User;
import com.sentix.infrastructure.persistence.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

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
}
