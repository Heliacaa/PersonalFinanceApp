package com.sentix.api.user;

import com.sentix.domain.User;
import com.sentix.infrastructure.persistence.UserRepository;
import com.sentix.test.TestDataFactory;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserControllerTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserController userController;

    private User user;

    @BeforeEach
    void setUp() {
        user = TestDataFactory.createUser();
    }

    @Nested
    @DisplayName("Toggle Paper Trading")
    class TogglePaperTrading {

        @Test
        @DisplayName("should enable paper trading when currently disabled")
        void shouldEnablePaperTrading() {
            user.setIsPaperTrading(false);
            when(userRepository.save(any(User.class))).thenReturn(user);

            ResponseEntity<UserResponse> response = userController.togglePaperTrading(user);

            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(response.getBody()).isNotNull();
            assertThat(response.getBody().getIsPaperTrading()).isTrue();
            verify(userRepository).save(user);
        }

        @Test
        @DisplayName("should disable paper trading when currently enabled")
        void shouldDisablePaperTrading() {
            user.setIsPaperTrading(true);
            when(userRepository.save(any(User.class))).thenReturn(user);

            ResponseEntity<UserResponse> response = userController.togglePaperTrading(user);

            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(response.getBody()).isNotNull();
            assertThat(response.getBody().getIsPaperTrading()).isFalse();
            verify(userRepository).save(user);
        }

        @Test
        @DisplayName("should return full UserResponse with all fields")
        void shouldReturnFullUserResponse() {
            user.setIsPaperTrading(false);
            user.setBalance(new BigDecimal("5000.00"));
            user.setPaperBalance(new BigDecimal("100000.00"));
            user.setPreferredCurrency("USD");
            when(userRepository.save(any(User.class))).thenReturn(user);

            ResponseEntity<UserResponse> response = userController.togglePaperTrading(user);

            UserResponse body = response.getBody();
            assertThat(body).isNotNull();
            assertThat(body.getFullName()).isEqualTo(user.getFullName());
            assertThat(body.getEmail()).isEqualTo(user.getEmail());
            assertThat(body.getBalance()).isEqualTo(new BigDecimal("5000.00"));
            assertThat(body.getPaperBalance()).isEqualTo(new BigDecimal("100000.00"));
            assertThat(body.getIsPaperTrading()).isTrue();
            assertThat(body.getPreferredCurrency()).isEqualTo("USD");
        }

        @Test
        @DisplayName("should handle null isPaperTrading as false and toggle to true")
        void shouldHandleNullIsPaperTrading() {
            user.setIsPaperTrading(null);
            when(userRepository.save(any(User.class))).thenReturn(user);

            ResponseEntity<UserResponse> response = userController.togglePaperTrading(user);

            assertThat(response.getBody()).isNotNull();
            assertThat(response.getBody().getIsPaperTrading()).isTrue();
        }

        @Test
        @DisplayName("should not throw when balance is null")
        void shouldNotThrowWhenBalanceIsNull() {
            user.setIsPaperTrading(false);
            user.setBalance(null);
            when(userRepository.save(any(User.class))).thenReturn(user);

            ResponseEntity<UserResponse> response = userController.togglePaperTrading(user);

            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(response.getBody()).isNotNull();
            assertThat(response.getBody().getBalance()).isNull();
        }

        @Test
        @DisplayName("should persist the toggled state")
        void shouldPersistToggledState() {
            user.setIsPaperTrading(false);
            when(userRepository.save(any(User.class))).thenReturn(user);

            userController.togglePaperTrading(user);

            ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
            verify(userRepository).save(captor.capture());
            assertThat(captor.getValue().getIsPaperTrading()).isTrue();
        }
    }

    @Nested
    @DisplayName("Get Current User")
    class GetCurrentUser {

        @Test
        @DisplayName("should return user profile")
        void shouldReturnUserProfile() {
            ResponseEntity<UserResponse> response = userController.getCurrentUser(user);

            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(response.getBody()).isNotNull();
            assertThat(response.getBody().getEmail()).isEqualTo(user.getEmail());
            assertThat(response.getBody().getFullName()).isEqualTo(user.getFullName());
        }
    }
}
