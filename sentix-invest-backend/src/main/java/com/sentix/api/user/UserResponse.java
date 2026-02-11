package com.sentix.api.user;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class UserResponse {
    private String fullName;
    private String email;
    private java.math.BigDecimal balance;
    private java.math.BigDecimal paperBalance;
    private Boolean isPaperTrading;
    private String preferredCurrency;
}
