package com.sentix.api.payment;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CheckoutFormResponse {
    private String checkoutFormContent; // HTML content to render in WebView
    private String token;
    private String conversationId;
    private String status;
    private String errorMessage;
}
