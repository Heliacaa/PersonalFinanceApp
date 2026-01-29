package com.sentix.infrastructure.payment;

import com.iyzipay.Options;
import com.iyzipay.model.Address;
import com.iyzipay.model.BasketItem;
import com.iyzipay.model.BasketItemType;
import com.iyzipay.model.Buyer;
import com.iyzipay.model.CheckoutFormInitialize;
import com.iyzipay.model.Currency;
import com.iyzipay.model.Locale;
import com.iyzipay.model.PaymentGroup;
import com.iyzipay.request.CreateCheckoutFormInitializeRequest;
import com.sentix.domain.User;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.Collections;
import java.util.List;

@Service
@RequiredArgsConstructor
public class IyzipayService {

    private final Options options;

    public CheckoutFormInitialize initializeCheckoutForm(User user, BigDecimal price, String callbackUrl) {
        CreateCheckoutFormInitializeRequest request = new CreateCheckoutFormInitializeRequest();
        request.setLocale(Locale.TR.getValue());
        request.setConversationId("123456789");
        request.setPrice(price);
        request.setPaidPrice(price);
        request.setCurrency(Currency.TRY.name());
        request.setBasketId("B12345");
        request.setPaymentGroup(PaymentGroup.PRODUCT.name());
        request.setCallbackUrl(callbackUrl);
        request.setEnabledInstallments(Collections.singletonList(1));

        Buyer buyer = new Buyer();
        buyer.setId(user.getId().toString());
        buyer.setName(user.getFullName().split(" ")[0]);
        buyer.setSurname(
                user.getFullName().contains(" ") ? user.getFullName().substring(user.getFullName().indexOf(" ") + 1)
                        : "");
        buyer.setGsmNumber("+905350000000"); // Demo value
        buyer.setEmail(user.getEmail());
        buyer.setIdentityNumber("74300864791"); // Demo value
        buyer.setLastLoginDate("2015-10-05 12:43:35");
        buyer.setRegistrationDate("2013-04-21 15:12:09");
        buyer.setRegistrationAddress("Nidakule Göztepe, Merdivenköy Mah. Bora Sok. No:1");
        buyer.setIp("85.34.78.112");
        buyer.setCity("Istanbul");
        buyer.setCountry("Turkey");
        request.setBuyer(buyer);

        Address shippingAddress = new Address();
        shippingAddress.setContactName(user.getFullName());
        shippingAddress.setCity("Istanbul");
        shippingAddress.setCountry("Turkey");
        shippingAddress.setAddress("Nidakule Göztepe, Merdivenköy Mah. Bora Sok. No:1");
        request.setShippingAddress(shippingAddress);

        Address billingAddress = new Address();
        billingAddress.setContactName(user.getFullName());
        billingAddress.setCity("Istanbul");
        billingAddress.setCountry("Turkey");
        billingAddress.setAddress("Nidakule Göztepe, Merdivenköy Mah. Bora Sok. No:1");
        request.setBillingAddress(billingAddress);

        BasketItem basketItem = new BasketItem();
        basketItem.setId("BI101");
        basketItem.setName("Premium Subscription");
        basketItem.setCategory1("Subscription");
        basketItem.setItemType(BasketItemType.VIRTUAL.name());
        basketItem.setPrice(price);
        request.setBasketItems(List.of(basketItem));

        return CheckoutFormInitialize.create(request, options);
    }
}
