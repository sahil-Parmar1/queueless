package com.queueless.customer_service.controller;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.queueless.customer_service.model.User;
import com.queueless.customer_service.service.CustomerQueueService;

@RestController
@RequestMapping("/api/queue")
public class CustomerQueueController {

    private final CustomerQueueService queueService;

    public CustomerQueueController(CustomerQueueService queueService) {
        this.queueService = queueService;
    }

    @PostMapping("/tokens/book")
    public ResponseEntity<?> bookToken(
            @RequestBody Map<String, Object> body,
            Authentication authentication) {

        if (authentication == null || !authentication.isAuthenticated() || "anonymousUser".equals(authentication.getPrincipal())) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                    "error", "Authentication required",
                    "message", "You must be logged in to generate a queue token."
            ));
        }

        if (body.get("officeId") == null || body.get("officeId").toString().isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "Office ID is required",
                    "message", "Office ID is required"
            ));
        }

        Long officeId = Long.valueOf(body.get("officeId").toString());
        Long providerId = body.get("providerId") != null && !body.get("providerId").toString().isBlank()
                ? Long.valueOf(body.get("providerId").toString())
                : null;
        String customerName = body.get("customerName") != null ? body.get("customerName").toString() : null;
        String customerPhone = body.get("customerPhone") != null ? body.get("customerPhone").toString() : null;
        String customerEmail = body.get("customerEmail") != null ? body.get("customerEmail").toString() : null;
        String taskDescription = body.get("taskDescription") != null ? body.get("taskDescription").toString().trim() : null;
        if (taskDescription != null && taskDescription.length() > 25) {
            taskDescription = taskDescription.substring(0, 25);
        }
        Long customerId = null;

        if (authentication.getPrincipal() instanceof User user) {
            customerId = user.getId();
            if (customerName == null || customerName.isBlank()) customerName = user.getName();
            if (customerEmail == null || customerEmail.isBlank()) customerEmail = user.getEmail();
        } else if (authentication.getName() != null) {
            if (customerEmail == null || customerEmail.isBlank()) customerEmail = authentication.getName();
        }

        try {
            Map<String, Object> result = queueService.bookToken(
                    officeId, providerId, customerId, customerName, customerPhone, customerEmail, taskDescription
            );
            return ResponseEntity.ok(result);
        } catch (IllegalStateException | IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", e.getMessage(),
                    "message", e.getMessage()
            ));
        }
    }

    @GetMapping("/tokens/my-active")
    public ResponseEntity<?> getMyActiveToken(
            @RequestParam(value = "email", required = false) String email,
            @RequestParam(value = "customerId", required = false) Long customerId,
            Authentication authentication) {

        if (authentication != null && authentication.getPrincipal() instanceof User user) {
            customerId = user.getId();
            email = user.getEmail();
        } else if (authentication != null && authentication.getName() != null && (email == null || email.isBlank())) {
            email = authentication.getName();
        }

        Map<String, Object> result = queueService.getMyActiveToken(customerId, email);
        return ResponseEntity.ok(result);
    }

    @GetMapping("/tokens/my-history")
    public ResponseEntity<?> getMyTokenHistory(
            @RequestParam(value = "email", required = false) String email,
            @RequestParam(value = "customerId", required = false) Long customerId,
            Authentication authentication) {

        if (authentication != null && authentication.getPrincipal() instanceof User user) {
            customerId = user.getId();
            email = user.getEmail();
        } else if (authentication != null && authentication.getName() != null && (email == null || email.isBlank())) {
            email = authentication.getName();
        }

        var result = queueService.getMyTokenHistory(customerId, email);
        return ResponseEntity.ok(result);
    }

    @PostMapping("/tokens/{id}/cancel")
    public ResponseEntity<?> cancelToken(
            @PathVariable("id") Long id,
            Authentication authentication) {

        Long customerId = null;
        String email = null;
        if (authentication != null) {
            if (authentication.getPrincipal() instanceof User user) {
                customerId = user.getId();
                email = user.getEmail();
            } else {
                email = authentication.getName();
            }
        }

        try {
            boolean success = queueService.cancelToken(id, customerId, email);
            return ResponseEntity.ok(Map.of(
                    "success", success,
                    "message", "Token cancelled successfully"
            ));
        } catch (IllegalStateException | IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", e.getMessage(),
                    "message", e.getMessage()
            ));
        }
    }

    @GetMapping("/office/{id}/live")
    public ResponseEntity<?> getOfficeLiveQueue(@PathVariable("id") Long id) {
        try {
            Map<String, Object> result = queueService.getLiveQueue(id);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                    "error", e.getMessage(),
                    "message", e.getMessage()
            ));
        }
    }
}
