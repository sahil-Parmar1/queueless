package com.queueless.office_service.websocket;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

    private final ProviderStatusWebSocketHandler providerStatusWebSocketHandler;

    public WebSocketConfig(ProviderStatusWebSocketHandler providerStatusWebSocketHandler) {
        this.providerStatusWebSocketHandler = providerStatusWebSocketHandler;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(providerStatusWebSocketHandler, "/ws/provider-status", "/ws")
                .setAllowedOrigins("*");
    }
}
