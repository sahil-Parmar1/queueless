package com.queueless.customer_service.controller;

import java.util.Collections;
import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.queueless.customer_service.model.User;
import com.queueless.customer_service.service.AiAssistantService;

@RestController
@RequestMapping
public class AiAssistantController {

    private final AiAssistantService aiAssistantService;

    public AiAssistantController(AiAssistantService aiAssistantService) {
        this.aiAssistantService = aiAssistantService;
    }

    @PostMapping({"/api/queue/ai/chat", "/api/queue/assistant/chat", "/api/ai/chat"})
    public ResponseEntity<?> chat(
            @RequestBody Map<String, Object> body,
            Authentication authentication) {

        String message = body.get("message") != null ? body.get("message").toString() : "";
        String email = body.get("email") != null ? body.get("email").toString() : null;
        Long customerId = null;

        if (authentication != null && authentication.getPrincipal() instanceof User user) {
            customerId = user.getId();
            email = user.getEmail();
        } else if (authentication != null && authentication.getName() != null && (email == null || email.isBlank())) {
            email = authentication.getName();
        }

        List<Map<String, String>> history = Collections.emptyList();
        Object rawHistory = body.get("history");
        if (rawHistory instanceof List<?> list) {
            try {
                history = (List<Map<String, String>>) (List<?>) list;
            } catch (Exception ignored) {}
        }

        Map<String, Object> response = aiAssistantService.processChat(customerId, email, message, history);
        return ResponseEntity.ok(response);
    }
}
