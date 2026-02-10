package com.sentix.api.ai;

import lombok.Data;

@Data
public class ChatRequest {
    private String message;
    private String symbol;
    private String sessionId;
}
