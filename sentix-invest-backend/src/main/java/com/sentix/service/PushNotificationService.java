package com.sentix.service;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
@Slf4j
public class PushNotificationService {

    /**
     * Send push notification to a specific device
     */
    public boolean sendNotification(String fcmToken, String title, String body, Map<String, String> data) {
        if (!isFirebaseInitialized()) {
            log.warn("Firebase not initialized - push notification skipped");
            return false;
        }

        try {
            Message.Builder messageBuilder = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .setAndroidConfig(AndroidConfig.builder()
                            .setPriority(AndroidConfig.Priority.HIGH)
                            .setNotification(AndroidNotification.builder()
                                    .setSound("default")
                                    .setChannelId("price_alerts")
                                    .build())
                            .build())
                    .setApnsConfig(ApnsConfig.builder()
                            .setAps(Aps.builder()
                                    .setSound("default")
                                    .setBadge(1)
                                    .build())
                            .build());

            if (data != null && !data.isEmpty()) {
                messageBuilder.putAllData(data);
            }

            String response = FirebaseMessaging.getInstance().send(messageBuilder.build());
            log.info("✅ Push notification sent: {}", response);
            return true;
        } catch (FirebaseMessagingException e) {
            log.error("❌ Failed to send push notification: {}", e.getMessage());
            return false;
        }
    }

    /**
     * Send price alert notification
     */
    public boolean sendPriceAlertNotification(
            String fcmToken,
            String symbol,
            String stockName,
            double targetPrice,
            double currentPrice,
            String alertType) {
        
        String title = "🔔 Price Alert: " + symbol;
        String body = String.format("%s has reached %s %.2f (Target: %.2f)",
                stockName, alertType.contains("ABOVE") ? "above" : "below",
                currentPrice, targetPrice);

        Map<String, String> data = Map.of(
                "type", "price_alert",
                "symbol", symbol,
                "targetPrice", String.valueOf(targetPrice),
                "currentPrice", String.valueOf(currentPrice),
                "alertType", alertType
        );

        return sendNotification(fcmToken, title, body, data);
    }

    /**
     * Send earnings reminder notification
     */
    public boolean sendEarningsReminderNotification(
            String fcmToken,
            String symbol,
            String stockName,
            String earningsDate,
            int daysUntil) {
        
        String title = "📊 Earnings Reminder: " + symbol;
        String body = String.format("%s reports earnings in %d day%s (%s)",
                stockName, daysUntil, daysUntil == 1 ? "" : "s", earningsDate);

        Map<String, String> data = Map.of(
                "type", "earnings_reminder",
                "symbol", symbol,
                "earningsDate", earningsDate
        );

        return sendNotification(fcmToken, title, body, data);
    }

    /**
     * Send dividend payment notification
     */
    public boolean sendDividendNotification(
            String fcmToken,
            String symbol,
            String stockName,
            double dividendAmount,
            String paymentDate) {
        
        String title = "💰 Dividend Payment: " + symbol;
        String body = String.format("%s dividend of $%.4f per share - Payment date: %s",
                stockName, dividendAmount, paymentDate);

        Map<String, String> data = Map.of(
                "type", "dividend_payment",
                "symbol", symbol,
                "amount", String.valueOf(dividendAmount),
                "paymentDate", paymentDate
        );

        return sendNotification(fcmToken, title, body, data);
    }

    /**
     * Send notification to a topic
     */
    public boolean sendTopicNotification(String topic, String title, String body) {
        if (!isFirebaseInitialized()) {
            log.warn("Firebase not initialized - topic notification skipped");
            return false;
        }

        try {
            Message message = Message.builder()
                    .setTopic(topic)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .build();

            String response = FirebaseMessaging.getInstance().send(message);
            log.info("✅ Topic notification sent to {}: {}", topic, response);
            return true;
        } catch (FirebaseMessagingException e) {
            log.error("❌ Failed to send topic notification: {}", e.getMessage());
            return false;
        }
    }

    private boolean isFirebaseInitialized() {
        return !FirebaseApp.getApps().isEmpty();
    }
}
