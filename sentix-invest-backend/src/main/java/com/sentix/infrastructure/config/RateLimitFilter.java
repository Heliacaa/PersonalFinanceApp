package com.sentix.infrastructure.config;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();

    @Value("${rate-limit.ai-analyze.requests:20}")
    private int aiAnalyzeRequests;

    @Value("${rate-limit.ai-analyze.minutes:1}")
    private int aiAnalyzeMinutes;

    @Value("${rate-limit.ai-chat.requests:10}")
    private int aiChatRequests;

    @Value("${rate-limit.ai-chat.minutes:1}")
    private int aiChatMinutes;

    @Value("${rate-limit.general.requests:60}")
    private int generalRequests;

    @Value("${rate-limit.general.minutes:1}")
    private int generalMinutes;

    @Value("${rate-limit.enabled:true}")
    private boolean rateLimitEnabled;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        if (!rateLimitEnabled) {
            filterChain.doFilter(request, response);
            return;
        }

        String clientIp = getClientIp(request);
        String path = request.getRequestURI();

        String bucketKey = clientIp + ":" + getBucketCategory(path);
        Bucket bucket = buckets.computeIfAbsent(bucketKey, k -> createBucket(path));

        if (bucket.tryConsume(1)) {
            filterChain.doFilter(request, response);
        } else {
            log.warn("Rate limit exceeded for IP: {} on path: {}", clientIp, path);
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setContentType("application/json");
            response.setHeader("Retry-After", "60");
            response.getWriter().write("{\"error\":\"Too many requests\",\"message\":\"Rate limit exceeded. Please try again later.\"}");
        }
    }

    private Bucket createBucket(String path) {
        if (path.startsWith("/api/v1/ai/analyze")) {
            return Bucket.builder()
                    .addLimit(Bandwidth.classic(aiAnalyzeRequests, Refill.greedy(aiAnalyzeRequests, Duration.ofMinutes(aiAnalyzeMinutes))))
                    .build();
        } else if (path.startsWith("/api/v1/ai/chat")) {
            return Bucket.builder()
                    .addLimit(Bandwidth.classic(aiChatRequests, Refill.greedy(aiChatRequests, Duration.ofMinutes(aiChatMinutes))))
                    .build();
        } else {
            return Bucket.builder()
                    .addLimit(Bandwidth.classic(generalRequests, Refill.greedy(generalRequests, Duration.ofMinutes(generalMinutes))))
                    .build();
        }
    }

    private String getBucketCategory(String path) {
        if (path.startsWith("/api/v1/ai/analyze")) return "ai-analyze";
        if (path.startsWith("/api/v1/ai/chat")) return "ai-chat";
        return "general";
    }

    private String getClientIp(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isEmpty()) {
            return xRealIp;
        }
        return request.getRemoteAddr();
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        // Don't rate limit health checks, swagger, or auth endpoints
        return path.startsWith("/actuator") ||
               path.startsWith("/swagger") ||
               path.startsWith("/v3/api-docs");
    }
}
