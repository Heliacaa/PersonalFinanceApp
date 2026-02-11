package com.sentix.infrastructure.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

class RateLimitFilterTest {

    private RateLimitFilter filter;
    private FilterChain filterChain;

    @BeforeEach
    void setUp() {
        filter = new RateLimitFilter();
        filterChain = mock(FilterChain.class);

        // Set property values via reflection (normally injected by Spring @Value)
        ReflectionTestUtils.setField(filter, "aiAnalyzeRequests", 3);
        ReflectionTestUtils.setField(filter, "aiAnalyzeMinutes", 1);
        ReflectionTestUtils.setField(filter, "aiChatRequests", 2);
        ReflectionTestUtils.setField(filter, "aiChatMinutes", 1);
        ReflectionTestUtils.setField(filter, "generalRequests", 5);
        ReflectionTestUtils.setField(filter, "generalMinutes", 1);
        ReflectionTestUtils.setField(filter, "rateLimitEnabled", true);
    }

    @Test
    @DisplayName("Requests within limit succeed with 200")
    void requestsWithinLimit_succeed() throws ServletException, IOException {
        for (int i = 0; i < 5; i++) {
            MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/stocks/AAPL");
            request.setRemoteAddr("192.168.1.1");
            MockHttpServletResponse response = new MockHttpServletResponse();

            filter.doFilter(request, response, filterChain);

            assertThat(response.getStatus()).isEqualTo(200);
        }
        verify(filterChain, times(5)).doFilter(any(), any());
    }

    @Test
    @DisplayName("Request exceeding limit returns 429")
    void requestExceedingLimit_returns429() throws ServletException, IOException {
        String ip = "10.0.0.1";

        // Exhaust the general bucket (limit = 5)
        for (int i = 0; i < 5; i++) {
            MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/portfolio");
            request.setRemoteAddr(ip);
            MockHttpServletResponse response = new MockHttpServletResponse();
            filter.doFilter(request, response, filterChain);
        }

        // 6th request should be rate limited
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/portfolio");
        request.setRemoteAddr(ip);
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(request, response, filterChain);

        assertThat(response.getStatus()).isEqualTo(429);
        assertThat(response.getHeader("Retry-After")).isEqualTo("60");
        assertThat(response.getContentAsString()).contains("Too many requests");
    }

    @Test
    @DisplayName("AI analyze endpoint has its own rate limit")
    void aiAnalyzeEndpoint_hasSeparateLimit() throws ServletException, IOException {
        String ip = "10.0.0.2";

        // Exhaust AI analyze bucket (limit = 3)
        for (int i = 0; i < 3; i++) {
            MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/ai/analyze");
            request.setRemoteAddr(ip);
            MockHttpServletResponse response = new MockHttpServletResponse();
            filter.doFilter(request, response, filterChain);
            assertThat(response.getStatus()).isEqualTo(200);
        }

        // 4th AI analyze request should be rate limited
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/ai/analyze");
        request.setRemoteAddr(ip);
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(request, response, filterChain);
        assertThat(response.getStatus()).isEqualTo(429);
    }

    @Test
    @DisplayName("AI chat endpoint has its own rate limit")
    void aiChatEndpoint_hasSeparateLimit() throws ServletException, IOException {
        String ip = "10.0.0.3";

        // Exhaust AI chat bucket (limit = 2)
        for (int i = 0; i < 2; i++) {
            MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/ai/chat");
            request.setRemoteAddr(ip);
            MockHttpServletResponse response = new MockHttpServletResponse();
            filter.doFilter(request, response, filterChain);
            assertThat(response.getStatus()).isEqualTo(200);
        }

        // 3rd AI chat request should be rate limited
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/ai/chat");
        request.setRemoteAddr(ip);
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(request, response, filterChain);
        assertThat(response.getStatus()).isEqualTo(429);
    }

    @Test
    @DisplayName("Different IPs have separate rate limit buckets")
    void differentIps_haveSeparateBuckets() throws ServletException, IOException {
        // Exhaust limit for IP1
        for (int i = 0; i < 5; i++) {
            MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/portfolio");
            request.setRemoteAddr("10.0.0.10");
            MockHttpServletResponse response = new MockHttpServletResponse();
            filter.doFilter(request, response, filterChain);
        }

        // IP1 should be rate limited
        MockHttpServletRequest blockedReq = new MockHttpServletRequest("GET", "/api/v1/portfolio");
        blockedReq.setRemoteAddr("10.0.0.10");
        MockHttpServletResponse blockedResp = new MockHttpServletResponse();
        filter.doFilter(blockedReq, blockedResp, filterChain);
        assertThat(blockedResp.getStatus()).isEqualTo(429);

        // IP2 should still work
        MockHttpServletRequest allowedReq = new MockHttpServletRequest("GET", "/api/v1/portfolio");
        allowedReq.setRemoteAddr("10.0.0.11");
        MockHttpServletResponse allowedResp = new MockHttpServletResponse();
        filter.doFilter(allowedReq, allowedResp, filterChain);
        assertThat(allowedResp.getStatus()).isEqualTo(200);
    }

    @Test
    @DisplayName("Rate limiting disabled passes all requests through")
    void rateLimitingDisabled_passesThrough() throws ServletException, IOException {
        ReflectionTestUtils.setField(filter, "rateLimitEnabled", false);

        // Even excessive requests should pass when disabled
        for (int i = 0; i < 100; i++) {
            MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/portfolio");
            request.setRemoteAddr("10.0.0.1");
            MockHttpServletResponse response = new MockHttpServletResponse();
            filter.doFilter(request, response, filterChain);
            assertThat(response.getStatus()).isEqualTo(200);
        }
    }

    @Test
    @DisplayName("Actuator endpoints are not rate limited")
    void actuatorEndpoints_notRateLimited() throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/actuator/health");
        request.setRemoteAddr("10.0.0.1");

        assertThat(filter.shouldNotFilter(request)).isTrue();
    }

    @Test
    @DisplayName("Swagger endpoints are not rate limited")
    void swaggerEndpoints_notRateLimited() throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/swagger-ui.html");
        request.setRemoteAddr("10.0.0.1");

        assertThat(filter.shouldNotFilter(request)).isTrue();
    }

    @Test
    @DisplayName("X-Forwarded-For header is used for client IP detection")
    void xForwardedFor_usedForClientIp() throws ServletException, IOException {
        // Exhaust limit for forwarded IP
        for (int i = 0; i < 5; i++) {
            MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/stocks/AAPL");
            request.setRemoteAddr("127.0.0.1");
            request.addHeader("X-Forwarded-For", "203.0.113.50");
            MockHttpServletResponse response = new MockHttpServletResponse();
            filter.doFilter(request, response, filterChain);
        }

        // Same forwarded IP should be rate limited
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/stocks/AAPL");
        request.setRemoteAddr("127.0.0.1");
        request.addHeader("X-Forwarded-For", "203.0.113.50");
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(request, response, filterChain);
        assertThat(response.getStatus()).isEqualTo(429);

        // Different forwarded IP should still work
        MockHttpServletRequest otherReq = new MockHttpServletRequest("GET", "/api/v1/stocks/AAPL");
        otherReq.setRemoteAddr("127.0.0.1");
        otherReq.addHeader("X-Forwarded-For", "203.0.113.51");
        MockHttpServletResponse otherResp = new MockHttpServletResponse();
        filter.doFilter(otherReq, otherResp, filterChain);
        assertThat(otherResp.getStatus()).isEqualTo(200);
    }
}
