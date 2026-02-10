package com.sentix.api.ai;

import lombok.Data;

import java.util.List;

@Data
public class ChatResponse {
    private String response;
    private List<ChatSource> sources;
    private String sessionId;

    @Data
    public static class ChatSource {
        private String title;
        private String sourceType;
        private String symbol;
        private double score;
    }
}
