package com.sentix.api.payment;

import com.sentix.domain.User;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;

    /**
     * Initialize iyzico checkout form
     * Returns HTML content that should be displayed in a WebView
     */
    @PostMapping("/checkout")
    public ResponseEntity<CheckoutFormResponse> initializeCheckout(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody PaymentRequest request,
            @RequestHeader(value = "X-Callback-Url", required = false) String callbackUrl) {
        // Use provided callback URL or default to backend callback page
        String effectiveCallbackUrl = callbackUrl != null && !callbackUrl.isBlank()
                ? callbackUrl
                : "http://localhost:8080/api/v1/payments/callback-page";
        CheckoutFormResponse response = paymentService.initializeCheckoutForm(user, request.getAmount(),
                effectiveCallbackUrl);

        if ("success".equals(response.getStatus())) {
            return ResponseEntity.ok(response);
        } else {
            return ResponseEntity.badRequest().body(response);
        }
    }

    /**
     * Callback endpoint for iyzico to call after payment
     * This receives the token and verifies the payment
     */
    @PostMapping("/callback")
    public ResponseEntity<PaymentCallbackResult> handleCallback(@RequestParam String token) {
        PaymentCallbackResult result = paymentService.handleCallback(token);
        // Always return 200 OK - the success/failure info is in the response body
        // This prevents confusing DioException errors in the frontend
        return ResponseEntity.ok(result);
    }

    /**
     * Simple callback page that iyzico redirects to
     * This page uses postMessage to communicate back to the parent window
     */
    @GetMapping("/callback-page")
    @ResponseBody
    public String callbackPage(@RequestParam String token) {
        // First handle the callback to verify payment
        PaymentCallbackResult result = paymentService.handleCallback(token);

        // Return a simple page that posts message to parent
        return """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Payment Processing</title>
                    <style>
                        body {
                            font-family: Arial, sans-serif;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            height: 100vh;
                            margin: 0;
                            background: #1a1a2e;
                            color: white;
                        }
                        .container { text-align: center; padding: 40px; }
                        .icon { font-size: 48px; margin-bottom: 20px; }
                        .success { color: #4CAF50; }
                        .error { color: #f44336; }
                        h1 { margin: 0 0 16px 0; }
                        p { color: #aaa; margin: 8px 0; }
                        .balance { font-size: 20px; color: #4CAF50; font-weight: bold; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="icon %s">%s</div>
                        <h1>%s</h1>
                        <p>%s</p>
                        %s
                        <p style="margin-top: 24px; font-size: 12px;">Click "Ödeme Durumu" to verify.</p>
                    </div>
                    <script>
                        // Notify parent window of payment completion
                        try {
                            window.parent.postMessage({
                                type: 'iyzico_callback',
                                status: '%s',
                                success: %s,
                                balance: %s
                            }, '*');
                        } catch (e) {
                            console.log('Could not post message to parent:', e);
                        }
                    </script>
                </body>
                </html>
                """
                .formatted(
                        result.isSuccess() ? "success" : "error",
                        result.isSuccess() ? "✓" : "✕",
                        result.isSuccess() ? "Payment Successful!" : "Payment Failed",
                        result.getMessage(),
                        result.isSuccess() && result.getNewBalance() != null
                                ? "<p class=\"balance\">New Balance: ₺" + String.format("%.2f", result.getNewBalance())
                                        + "</p>"
                                : "",
                        result.isSuccess() ? "success" : "failure",
                        result.isSuccess() ? "true" : "false",
                        result.getNewBalance() != null ? result.getNewBalance() : "null");
    }

    /**
     * POST callback endpoint that iyzico can call directly
     * (Alternative to GET callback-page for form-based callbacks)
     */
    @PostMapping("/callback-page")
    @ResponseBody
    public String callbackPagePost(@RequestParam String token) {
        return callbackPage(token);
    }
}
