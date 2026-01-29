package com.sentix.api.payment;

import com.iyzipay.Options;
import com.iyzipay.model.*;
import com.iyzipay.request.CreateCheckoutFormInitializeRequest;
import com.iyzipay.request.RetrieveCheckoutFormRequest;
import com.sentix.domain.Payment;
import com.sentix.domain.PaymentStatus;
import com.sentix.domain.User;
import com.sentix.infrastructure.persistence.PaymentRepository;
import com.sentix.infrastructure.persistence.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final Options iyzipayOptions;
    private final PaymentRepository paymentRepository;
    private final UserRepository userRepository;

    /**
     * Initialize iyzico Checkout Form for a payment
     */
    public CheckoutFormResponse initializeCheckoutForm(User user, BigDecimal amount, String callbackUrl) {
        String conversationId = UUID.randomUUID().toString();

        // Create payment record
        Payment payment = Payment.builder()
                .userId(user.getId())
                .amount(amount)
                .status(PaymentStatus.PENDING)
                .conversationId(conversationId)
                .build();
        paymentRepository.save(payment);

        try {
            CreateCheckoutFormInitializeRequest request = new CreateCheckoutFormInitializeRequest();
            request.setLocale(Locale.TR.getValue());
            request.setConversationId(conversationId);
            request.setPrice(amount);
            request.setPaidPrice(amount);
            request.setCurrency(Currency.TRY.name());
            request.setBasketId("B" + payment.getId().toString().substring(0, 8));
            request.setPaymentGroup(PaymentGroup.PRODUCT.name());
            request.setCallbackUrl(callbackUrl);
            request.setEnabledInstallments(List.of(1)); // Only single payment

            // Buyer info
            Buyer buyer = new Buyer();
            buyer.setId(user.getId().toString());
            buyer.setName(getFirstName(user.getFullName()));
            buyer.setSurname(getLastName(user.getFullName()));
            buyer.setEmail(user.getEmail());
            buyer.setIdentityNumber("11111111111"); // Sandbox placeholder
            buyer.setRegistrationAddress("Istanbul, Turkey");
            buyer.setCity("Istanbul");
            buyer.setCountry("Turkey");
            buyer.setIp("127.0.0.1");
            request.setBuyer(buyer);

            // Address (required but can use placeholder for digital goods)
            Address address = new Address();
            address.setContactName(user.getFullName());
            address.setCity("Istanbul");
            address.setCountry("Turkey");
            address.setAddress("Istanbul, Turkey");
            request.setShippingAddress(address);
            request.setBillingAddress(address);

            // Basket items
            List<BasketItem> basketItems = new ArrayList<>();
            BasketItem item = new BasketItem();
            item.setId("BI001");
            item.setName("Account Top-up");
            item.setCategory1("Digital Services");
            item.setItemType(BasketItemType.VIRTUAL.name());
            item.setPrice(amount);
            basketItems.add(item);
            request.setBasketItems(basketItems);

            // Call iyzico API
            CheckoutFormInitialize checkoutForm = CheckoutFormInitialize.create(request, iyzipayOptions);

            if ("success".equals(checkoutForm.getStatus())) {
                // Update payment with token
                payment.setIyzicoToken(checkoutForm.getToken());
                paymentRepository.save(payment);

                return CheckoutFormResponse.builder()
                        .checkoutFormContent(checkoutForm.getCheckoutFormContent())
                        .token(checkoutForm.getToken())
                        .conversationId(conversationId)
                        .status("success")
                        .build();
            } else {
                payment.setStatus(PaymentStatus.FAILED);
                paymentRepository.save(payment);

                log.error("iyzico checkout form failed: {}", checkoutForm.getErrorMessage());
                return CheckoutFormResponse.builder()
                        .status("failure")
                        .errorMessage(checkoutForm.getErrorMessage())
                        .build();
            }
        } catch (Exception e) {
            payment.setStatus(PaymentStatus.FAILED);
            paymentRepository.save(payment);

            log.error("Error creating checkout form", e);
            return CheckoutFormResponse.builder()
                    .status("failure")
                    .errorMessage("Payment initialization failed: " + e.getMessage())
                    .build();
        }
    }

    /**
     * Handle callback from iyzico after payment completion
     */
    @Transactional
    public PaymentCallbackResult handleCallback(String token) {
        try {
            RetrieveCheckoutFormRequest request = new RetrieveCheckoutFormRequest();
            request.setToken(token);

            CheckoutForm checkoutForm = CheckoutForm.retrieve(request, iyzipayOptions);

            Payment payment = paymentRepository.findByIyzicoToken(token)
                    .orElseThrow(() -> new RuntimeException("Payment not found for token: " + token));

            if ("success".equals(checkoutForm.getPaymentStatus())) {
                payment.setStatus(PaymentStatus.SUCCESS);
                payment.setIyzicoPaymentId(checkoutForm.getPaymentId());
                paymentRepository.save(payment);

                // Update user balance
                User user = userRepository.findById(payment.getUserId())
                        .orElseThrow(() -> new RuntimeException("User not found"));

                BigDecimal newBalance = user.getBalance().add(payment.getAmount());
                user.setBalance(newBalance);
                userRepository.save(user);

                log.info("Payment successful for user {}: {} TL", user.getId(), payment.getAmount());

                return PaymentCallbackResult.builder()
                        .success(true)
                        .message("Payment successful! Your balance has been updated.")
                        .newBalance(newBalance)
                        .build();
            } else {
                payment.setStatus(PaymentStatus.FAILED);
                paymentRepository.save(payment);

                log.warn("Payment failed for token {}: {}", token, checkoutForm.getErrorMessage());

                return PaymentCallbackResult.builder()
                        .success(false)
                        .message("Payment failed: " + checkoutForm.getErrorMessage())
                        .build();
            }
        } catch (Exception e) {
            log.error("Error handling payment callback", e);
            return PaymentCallbackResult.builder()
                    .success(false)
                    .message("Error processing payment: " + e.getMessage())
                    .build();
        }
    }

    private String getFirstName(String fullName) {
        if (fullName == null || fullName.isBlank())
            return "User";
        String[] parts = fullName.trim().split("\\s+");
        return parts[0];
    }

    private String getLastName(String fullName) {
        if (fullName == null || fullName.isBlank())
            return "User";
        String[] parts = fullName.trim().split("\\s+");
        return parts.length > 1 ? parts[parts.length - 1] : parts[0];
    }
}
