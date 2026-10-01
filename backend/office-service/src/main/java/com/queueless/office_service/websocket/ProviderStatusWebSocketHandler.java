package com.queueless.office_service.websocket;

import java.io.IOException;
import java.util.Collections;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

@Component
public class ProviderStatusWebSocketHandler extends TextWebSocketHandler {

    private static final Logger log = LoggerFactory.getLogger(ProviderStatusWebSocketHandler.class);

    private final Set<WebSocketSession> sessions = Collections.newSetFromMap(new ConcurrentHashMap<>());

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        sessions.add(session);
        log.info("WebSocket client connected: session id={}. Total connected={}", session.getId(), sessions.size());
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        sessions.remove(session);
        log.info("WebSocket client disconnected: session id={}, status={}. Total connected={}", 
                session.getId(), status, sessions.size());
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) {
        log.warn("WebSocket transport error for session {}: {}", session.getId(), exception.getMessage());
        try {
            session.close(CloseStatus.SERVER_ERROR);
        } catch (IOException ignored) {}
        sessions.remove(session);
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        // Echo / ping acknowledgment
        try {
            if ("ping".equalsIgnoreCase(message.getPayload().trim())) {
                session.sendMessage(new TextMessage("{\"type\":\"PONG\"}"));
            }
        } catch (IOException e) {
            log.warn("Error replying to ping: {}", e.getMessage());
        }
    }

    /**
     * Broadcasts real-time provider duty status change to all connected office and customer clients.
     */
    public void broadcastProviderStatus(Long officeId, Long providerId, boolean onDuty, boolean availableNow) {
        String jsonPayload = String.format(
                "{\"event\":\"PROVIDER_STATUS_CHANGED\",\"officeId\":%d,\"providerId\":%d,\"onDuty\":%b,\"availableNow\":%b,\"timestamp\":%d}",
                officeId != null ? officeId : -1,
                providerId != null ? providerId : -1,
                onDuty,
                availableNow,
                System.currentTimeMillis()
        );

        TextMessage textMessage = new TextMessage(jsonPayload);
        log.info("Broadcasting provider duty status update: {} to {} sessions", jsonPayload, sessions.size());

        for (WebSocketSession session : sessions) {
            if (session.isOpen()) {
                try {
                    synchronized (session) {
                        session.sendMessage(textMessage);
                    }
                } catch (IOException e) {
                    log.warn("Failed to send WebSocket message to session {}: {}", session.getId(), e.getMessage());
                }
            }
        }
    }

    /**
     * Broadcasts real-time office open/closed status change to all connected office and customer clients.
     */
    public void broadcastOfficeStatus(Long officeId, boolean isOpen) {
        String jsonPayload = String.format(
                "{\"event\":\"OFFICE_STATUS_CHANGED\",\"officeId\":%d,\"isOpen\":%b,\"timestamp\":%d}",
                officeId != null ? officeId : -1,
                isOpen,
                System.currentTimeMillis()
        );

        TextMessage textMessage = new TextMessage(jsonPayload);
        log.info("Broadcasting office open status update: {} to {} sessions", jsonPayload, sessions.size());

        for (WebSocketSession session : sessions) {
            if (session.isOpen()) {
                try {
                    synchronized (session) {
                        session.sendMessage(textMessage);
                    }
                } catch (IOException e) {
                    log.warn("Failed to send WebSocket message to session {}: {}", session.getId(), e.getMessage());
                }
            }
        }
    }
}
