package com.sentix.api.alert;

import com.sentix.api.stock.StockQuoteDto;
import com.sentix.api.stock.StockService;
import com.sentix.domain.AlertType;
import com.sentix.domain.PriceAlert;
import com.sentix.domain.User;
import com.sentix.infrastructure.persistence.PriceAlertRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PriceAlertService {

    private final PriceAlertRepository priceAlertRepository;
    private final StockService stockService;

    @Transactional
    public PriceAlertResponse createAlert(User user, CreateAlertRequest request) {
        AlertType alertType;
        try {
            alertType = AlertType.valueOf(request.getAlertType().toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException(
                    "Invalid alert type. Must be ABOVE, BELOW, PERCENT_CHANGE, EARNINGS_REMINDER, or DIVIDEND_PAYMENT");
        }

        PriceAlert alert = PriceAlert.builder()
                .user(user)
                .symbol(request.getSymbol().toUpperCase())
                .stockName(request.getStockName())
                .targetPrice(request.getTargetPrice())
                .referencePrice(request.getReferencePrice())
                .daysNotice(request.getDaysNotice())
                .alertType(alertType)
                .isActive(true)
                .build();

        PriceAlert savedAlert = priceAlertRepository.save(alert);
        log.info("Created price alert {} for user {} on symbol {}",
                savedAlert.getId(), user.getId(), savedAlert.getSymbol());

        return mapToResponse(savedAlert);
    }

    public List<PriceAlertResponse> getUserAlerts(User user) {
        List<PriceAlert> alerts = priceAlertRepository.findByUser(user);
        return alerts.stream()
                .map(this::mapToResponse)
                .toList();
    }

    public List<PriceAlertResponse> getActiveAlerts(User user) {
        List<PriceAlert> alerts = priceAlertRepository.findByUserAndIsActiveTrue(user);
        return alerts.stream()
                .map(this::mapToResponse)
                .toList();
    }

    public List<PriceAlertResponse> getAlertsBySymbol(User user, String symbol) {
        List<PriceAlert> alerts = priceAlertRepository.findByUserAndSymbol(user, symbol.toUpperCase());
        return alerts.stream()
                .map(this::mapToResponse)
                .toList();
    }

    @Transactional
    public void deleteAlert(User user, UUID alertId) {
        PriceAlert alert = priceAlertRepository.findById(alertId)
                .orElseThrow(() -> new IllegalArgumentException("Alert not found"));

        if (!alert.getUser().getId().equals(user.getId())) {
            throw new IllegalArgumentException("Alert does not belong to user");
        }

        priceAlertRepository.delete(alert);
        log.info("Deleted price alert {} for user {}", alertId, user.getId());
    }

    @Transactional
    public PriceAlertResponse toggleAlert(User user, UUID alertId) {
        PriceAlert alert = priceAlertRepository.findById(alertId)
                .orElseThrow(() -> new IllegalArgumentException("Alert not found"));

        if (!alert.getUser().getId().equals(user.getId())) {
            throw new IllegalArgumentException("Alert does not belong to user");
        }

        alert.setIsActive(!alert.getIsActive());
        PriceAlert savedAlert = priceAlertRepository.save(alert);
        log.info("Toggled alert {} to active={}", alertId, savedAlert.getIsActive());

        return mapToResponse(savedAlert);
    }

    /**
     * Check all active alerts and return any that have been triggered.
     * This can be called by a scheduled job.
     */
    @Transactional
    public List<PriceAlertResponse> checkAndTriggerAlerts() {
        List<PriceAlert> activeAlerts = priceAlertRepository.findByIsActiveTrue();
        List<PriceAlertResponse> triggeredAlerts = new ArrayList<>();

        for (PriceAlert alert : activeAlerts) {
            try {
                boolean triggered = false;

                if (alert.getAlertType() == AlertType.EARNINGS_REMINDER) {
                    Map<String, Object> earnings = stockService.getEarnings(alert.getSymbol());
                    if (earnings != null && earnings.containsKey("nextEarningsDate")) {
                        String dateStr = (String) earnings.get("nextEarningsDate");
                        if (dateStr != null) {
                            LocalDateTime earningsDate = java.time.LocalDate.parse(dateStr).atStartOfDay();
                            int daysNotice = alert.getDaysNotice() != null ? alert.getDaysNotice() : 1;
                            if (LocalDateTime.now().plusDays(daysNotice).isAfter(earningsDate)) {
                                triggered = true;
                            }
                        }
                    }
                } else if (alert.getAlertType() == AlertType.DIVIDEND_PAYMENT) {
                    Map<String, Object> dividends = stockService.getDividends(alert.getSymbol());
                    if (dividends != null && dividends.containsKey("nextDividend")) {
                        Map<String, Object> nextDiv = (Map<String, Object>) dividends.get("nextDividend");
                        if (nextDiv != null && nextDiv.containsKey("paymentDate")) {
                            String dateStr = (String) nextDiv.get("paymentDate");
                            if (dateStr != null) {
                                LocalDateTime paymentDate = java.time.LocalDate.parse(dateStr).atStartOfDay();
                                int daysNotice = alert.getDaysNotice() != null ? alert.getDaysNotice() : 1;
                                if (LocalDateTime.now().plusDays(daysNotice).isAfter(paymentDate)) {
                                    triggered = true;
                                }
                            }
                        }
                    }
                } else {
                    // Price based alerts
                    StockQuoteDto quote = stockService.getStockQuote(alert.getSymbol());
                    if (quote != null) {
                        BigDecimal currentPrice = BigDecimal.valueOf(quote.getPrice());

                        if (alert.getAlertType() == AlertType.ABOVE &&
                                currentPrice.compareTo(alert.getTargetPrice()) >= 0) {
                            triggered = true;
                        } else if (alert.getAlertType() == AlertType.BELOW &&
                                currentPrice.compareTo(alert.getTargetPrice()) <= 0) {
                            triggered = true;
                        } else if (alert.getAlertType() == AlertType.PERCENT_CHANGE
                                && alert.getReferencePrice() != null) {
                            BigDecimal diff = currentPrice.subtract(alert.getReferencePrice()).abs();
                            BigDecimal percentDiff = diff
                                    .divide(alert.getReferencePrice(), 4, java.math.RoundingMode.HALF_UP)
                                    .multiply(BigDecimal.valueOf(100));
                            if (percentDiff.compareTo(alert.getTargetPrice()) >= 0) { // targetPrice is used as
                                                                                      // percentage threshold here
                                triggered = true;
                            }
                        }
                    }
                }

                if (triggered) {
                    alert.setIsActive(false);
                    alert.setTriggeredAt(LocalDateTime.now());
                    priceAlertRepository.save(alert);
                    triggeredAlerts.add(mapToResponse(alert));
                    log.info("Alert {} triggered for {} type {}",
                            alert.getId(), alert.getSymbol(), alert.getAlertType());
                }
            } catch (Exception e) {
                log.warn("Error checking alert {} for {}: {}",
                        alert.getId(), alert.getSymbol(), e.getMessage());
            }
        }

        return triggeredAlerts;
    }

    private PriceAlertResponse mapToResponse(PriceAlert alert) {
        BigDecimal currentPrice = BigDecimal.ZERO;
        try {
            StockQuoteDto quote = stockService.getStockQuote(alert.getSymbol());
            if (quote != null) {
                currentPrice = BigDecimal.valueOf(quote.getPrice());
            }
        } catch (Exception e) {
            log.warn("Could not fetch current price for {}: {}", alert.getSymbol(), e.getMessage());
        }

        return PriceAlertResponse.builder()
                .id(alert.getId())
                .symbol(alert.getSymbol())
                .stockName(alert.getStockName())
                .targetPrice(alert.getTargetPrice())
                .currentPrice(currentPrice)
                .alertType(alert.getAlertType().name())
                .isActive(alert.getIsActive())
                .createdAt(alert.getCreatedAt())
                .triggeredAt(alert.getTriggeredAt())
                .build();
    }
}
