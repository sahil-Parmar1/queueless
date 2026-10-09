package com.queueless.office_service.queue;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.queueless.office_service.user.User;

@RestController
@RequestMapping("/api/queue")
public class QueueController {

    private final QueueService queueService;

    public QueueController(QueueService queueService) {
        this.queueService = queueService;
    }

    /**
     * Book a token for an office.
     */
    @PostMapping("/tokens/book")
    public ResponseEntity<?> bookToken(
            @RequestBody Map<String, Object> body,
            Authentication authentication) {

        if (authentication == null || !authentication.isAuthenticated() || "anonymousUser".equals(authentication.getPrincipal())) {
            return ResponseEntity.status(org.springframework.http.HttpStatus.UNAUTHORIZED).body(Map.of(
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

    /**
     * Get active token for logged-in or identified customer.
     */
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

    /**
     * Get customer token history.
     */
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

        return ResponseEntity.ok(queueService.getMyTokenHistory(customerId, email));
    }

    /**
     * Cancel a booked token.
     */
    @PostMapping("/tokens/{id}/cancel")
    public ResponseEntity<?> cancelToken(@PathVariable("id") Long id) {
        return ResponseEntity.ok(queueService.cancelToken(id));
    }

    /**
     * Get live queue information for an office.
     */
    @GetMapping("/office/{officeId}/live")
    public ResponseEntity<?> getLiveQueue(@PathVariable("officeId") Long officeId) {
        return ResponseEntity.ok(queueService.getLiveQueue(officeId));
    }

    /**
     * Office operator calls next customer.
     */
    @PostMapping("/office/{officeId}/call-next")
    public ResponseEntity<?> callNext(@PathVariable("officeId") Long officeId) {
        return ResponseEntity.ok(queueService.callNext(officeId));
    }

    /**
     * Office operator completes current customer.
     */
    @PostMapping("/office/{officeId}/complete")
    public ResponseEntity<?> completeCurrent(@PathVariable("officeId") Long officeId) {
        return ResponseEntity.ok(queueService.completeCurrent(officeId));
    }

    /**
     * Office operator skips/holds current customer.
     */
    @PostMapping("/office/{officeId}/skip")
    public ResponseEntity<?> skipCurrent(@PathVariable("officeId") Long officeId) {
        return ResponseEntity.ok(queueService.skipCurrent(officeId));
    }

    /**
     * Office operator swaps current customer with the next waiting customer.
     */
    @PostMapping("/office/{officeId}/swap-next")
    public ResponseEntity<?> swapNext(@PathVariable("officeId") Long officeId) {
        try {
            return ResponseEntity.ok(queueService.swapNext(officeId));
        } catch (IllegalStateException | IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    /**
     * Office operator forwards an unassigned or waiting token to an available provider.
     */
    @PostMapping("/office/{officeId}/tokens/{tokenId}/forward")
    public ResponseEntity<?> forwardToken(
            @PathVariable("officeId") Long officeId,
            @PathVariable("tokenId") Long tokenId,
            @RequestBody Map<String, Object> body) {
        if (!body.containsKey("providerId") || body.get("providerId") == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "providerId is required", "message", "Provider ID is required"));
        }
        Long providerId = Long.valueOf(body.get("providerId").toString());
        try {
            return ResponseEntity.ok(queueService.forwardTokenToProvider(officeId, tokenId, providerId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    /**
     * Office operator serves an unassigned token directly at desk counter.
     */
    @PostMapping("/office/{officeId}/tokens/{tokenId}/serve")
    public ResponseEntity<?> serveTokenAtDesk(
            @PathVariable("officeId") Long officeId,
            @PathVariable("tokenId") Long tokenId) {
        try {
            return ResponseEntity.ok(queueService.serveTokenAtDesk(officeId, tokenId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    /**
     * Office operator requests a provider to accept a token when provider limit is reached.
     */
    @PostMapping("/office/{officeId}/tokens/{tokenId}/request-forward")
    public ResponseEntity<?> requestForwardToken(
            @PathVariable("officeId") Long officeId,
            @PathVariable("tokenId") Long tokenId,
            @RequestBody Map<String, Object> body) {
        if (!body.containsKey("providerId") || body.get("providerId") == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "providerId is required", "message", "Provider ID is required"));
        }
        Long providerId = Long.valueOf(body.get("providerId").toString());
        try {
            return ResponseEntity.ok(queueService.requestTokenToProvider(officeId, tokenId, providerId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    /**
     * Office operator cancels a pending token request.
     */
    @PostMapping("/office/{officeId}/tokens/{tokenId}/cancel-request")
    public ResponseEntity<?> cancelTokenRequest(
            @PathVariable("officeId") Long officeId,
            @PathVariable("tokenId") Long tokenId) {
        try {
            return ResponseEntity.ok(queueService.cancelTokenRequest(officeId, tokenId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    /**
     * Office operator forwards a priority request to a provider.
     */
    @PostMapping("/office/{officeId}/priority-requests/{tokenId}/forward")
    public ResponseEntity<?> forwardPriorityRequest(
            @PathVariable("officeId") Long officeId,
            @PathVariable("tokenId") Long tokenId,
            @RequestBody Map<String, Object> body) {
        if (!body.containsKey("providerId") || body.get("providerId") == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "providerId is required", "message", "Provider ID is required"));
        }
        Long providerId = Long.valueOf(body.get("providerId").toString());
        try {
            return ResponseEntity.ok(queueService.officeForwardPriority(officeId, tokenId, providerId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    /**
     * Office operator rejects a priority request.
     */
    @PostMapping("/office/{officeId}/priority-requests/{tokenId}/reject")
    public ResponseEntity<?> rejectPriorityRequest(
            @PathVariable("officeId") Long officeId,
            @PathVariable("tokenId") Long tokenId) {
        try {
            return ResponseEntity.ok(queueService.officeRejectPriority(officeId, tokenId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }
}

