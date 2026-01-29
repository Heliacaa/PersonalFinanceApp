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
            @RequestHeader(value = "X-Callback-Url", defaultValue = "http://localhost:8080/api/v1/payments/callback-page") String callbackUrl) {
        CheckoutFormResponse response = paymentService.initializeCheckoutForm(user, request.getAmount(), callbackUrl);

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

        if (result.isSuccess()) {
            return ResponseEntity.ok(result);
        } else {
            return ResponseEntity.badRequest().body(result);
        }
    }

    /**
     * Callback page that iyzico redirects to
     * This page calls the callback endpoint and shows result to user
     */
    @GetMapping("/callback-page")
    @ResponseBody
    public String callbackPage(@RequestParam String token) {
        PaymentCallbackResult result = paymentService.handleCallback(token);

        if (result.isSuccess()) {
            return """
                    <!DOCTYPE html>
                    <html>
                    <head>
                        <meta charset="UTF-8">
                        <meta name="viewport" content="width=device-width, initial-scale=1.0">
                        <title>Payment Successful</title>
                        <style>
                            body { font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #1a1a2e; color: white; }
                            .container { text-align: center; padding: 40px; }
                            .success { color: #4CAF50; font-size: 48px; }
                            h1 { color: #4CAF50; }
                            .balance { font-size: 24px; margin: 20px 0; }
                        </style>
                    </head>
                    <body>
                        <div class="container">
                            <div class="success">✓</div>
                            <h1>Payment Successful!</h1>
                            <p>%s</p>
                            <p class="balance">New Balance: ₺%.2f</p>
                            <p>You can close this window and return to the app.</p>
                            <script>
                                // Signal to Flutter WebView that payment is complete
                                if (window.flutter_inappwebview) {
                                    window.flutter_inappwebview.callHandler('paymentComplete', { success: true, balance: %.2f });
                                }
                            </script>
                        </div>
                    </body>
                    </html>
                    """
                    .formatted(result.getMessage(), result.getNewBalance(), result.getNewBalance());
        } else {
            return """
                    <!DOCTYPE html>
                    <html>
                    <head>
                        <meta charset="UTF-8">
                        <meta name="viewport" content="width=device-width, initial-scale=1.0">
                        <title>Payment Failed</title>
                        <style>
                            body { font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #1a1a2e; color: white; }
                            .container { text-align: center; padding: 40px; }
                            .error { color: #f44336; font-size: 48px; }
                            h1 { color: #f44336; }
                        </style>
                    </head>
                    <body>
                        <div class="container">
                            <div class="error">✕</div>
                            <h1>Payment Failed</h1>
                            <p>%s</p>
                            <p>Please try again or contact support.</p>
                            <script>
                                if (window.flutter_inappwebview) {
                                    window.flutter_inappwebview.callHandler('paymentComplete', { success: false });
                                }
                            </script>
                        </div>
                    </body>
                    </html>
                    """
                    .formatted(result.getMessage());
        }
    }
}
