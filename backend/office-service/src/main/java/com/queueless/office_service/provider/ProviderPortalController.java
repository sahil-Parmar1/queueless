package com.queueless.office_service.provider;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.queueless.office_service.provider.dto.ProviderLoginRequest;
import com.queueless.office_service.provider.dto.ProviderResponse;
import com.queueless.office_service.queue.QueueService;

@RestController
public class ProviderPortalController {

    private final ProviderService providerService;
    private final QueueService queueService;

    public ProviderPortalController(ProviderService providerService, QueueService queueService) {
        this.providerService = providerService;
        this.queueService = queueService;
    }

    @PostMapping({"/api/provider/login", "/api/office/provider/login", "/api/office/providers/login"})
    public ResponseEntity<?> login(@RequestBody ProviderLoginRequest request) {
        Map<String, Object> response = providerService.loginProvider(request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/api/provider/me")
    public ResponseEntity<?> getCurrentProvider(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        ProviderResponse response = providerService.getCurrentProviderDetails(provider.getId());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/api/provider/settings/queue")
    public ResponseEntity<?> getQueueSettings(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        return ResponseEntity.ok(providerService.getProviderQueueSettings(provider.getId()));
    }

    @org.springframework.web.bind.annotation.PutMapping("/api/provider/settings/queue")
    public ResponseEntity<?> updateQueueSettings(
            @RequestBody com.queueless.office_service.provider.dto.ProviderQueueSettingsRequest request,
            Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        try {
            return ResponseEntity.ok(providerService.updateProviderQueueSettings(provider.getId(), request));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    @org.springframework.web.bind.annotation.PutMapping("/api/provider/duty-status")
    public ResponseEntity<?> updateDutyStatus(
            @RequestBody Map<String, Object> request,
            Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        Object dutyVal = request.get("onDuty");
        if (dutyVal == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Missing required field: onDuty"));
        }
        boolean onDuty = Boolean.parseBoolean(dutyVal.toString());
        ProviderResponse response = providerService.updateDutyStatus(provider.getId(), onDuty);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/api/provider/tokens/history")
    public ResponseEntity<?> getProviderTokenHistory(
            @org.springframework.web.bind.annotation.RequestParam(value = "search", required = false) String search,
            @org.springframework.web.bind.annotation.RequestParam(value = "status", required = false) String status,
            @org.springframework.web.bind.annotation.RequestParam(value = "date", required = false) String date,
            @org.springframework.web.bind.annotation.RequestParam(value = "startDate", required = false) String startDateStr,
            @org.springframework.web.bind.annotation.RequestParam(value = "endDate", required = false) String endDateStr,
            @org.springframework.web.bind.annotation.RequestParam(value = "page", defaultValue = "0") int page,
            @org.springframework.web.bind.annotation.RequestParam(value = "size", defaultValue = "20") int size,
            Authentication authentication) {

        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }

        java.time.LocalDate startDate = null;
        java.time.LocalDate endDate = null;

        if (date != null && !date.isBlank()) {
            String d = date.trim().toLowerCase();
            if ("today".equals(d)) {
                startDate = java.time.LocalDate.now();
                endDate = startDate;
            } else if ("yesterday".equals(d)) {
                startDate = java.time.LocalDate.now().minusDays(1);
                endDate = startDate;
            } else if ("7_days".equals(d) || "this_week".equals(d)) {
                startDate = java.time.LocalDate.now().minusDays(7);
                endDate = java.time.LocalDate.now();
            } else if ("this_month".equals(d)) {
                startDate = java.time.LocalDate.now().withDayOfMonth(1);
                endDate = java.time.LocalDate.now();
            } else {
                try {
                    startDate = java.time.LocalDate.parse(date.trim());
                    endDate = startDate;
                } catch (Exception ignored) {}
            }
        }
        if (startDateStr != null && !startDateStr.isBlank()) {
            try {
                startDate = java.time.LocalDate.parse(startDateStr.trim());
            } catch (Exception ignored) {}
        }
        if (endDateStr != null && !endDateStr.isBlank()) {
            try {
                endDate = java.time.LocalDate.parse(endDateStr.trim());
            } catch (Exception ignored) {}
        }

        Map<String, Object> result = queueService.getProviderTokenHistory(
                provider.getId(), search, status, startDate, endDate, page, size
        );
        return ResponseEntity.ok(result);
    }

    @GetMapping("/api/provider/queue/live")
    public ResponseEntity<?> getProviderLiveQueue(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        return ResponseEntity.ok(queueService.getProviderLiveQueue(provider.getId()));
    }

    @PostMapping("/api/provider/queue/call-next")
    public ResponseEntity<?> providerCallNext(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        return ResponseEntity.ok(queueService.providerCallNext(provider.getId()));
    }

    @PostMapping("/api/provider/queue/tokens/{id}/serve")
    public ResponseEntity<?> providerServeToken(
            @org.springframework.web.bind.annotation.PathVariable("id") Long id,
            Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        try {
            return ResponseEntity.ok(queueService.providerServeToken(provider.getId(), id));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    @PostMapping("/api/provider/queue/complete")
    public ResponseEntity<?> providerCompleteCurrent(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        return ResponseEntity.ok(queueService.providerCompleteCurrent(provider.getId()));
    }

    @PostMapping("/api/provider/queue/skip")
    public ResponseEntity<?> providerSkipCurrent(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        return ResponseEntity.ok(queueService.providerSkipCurrent(provider.getId()));
    }

    @PostMapping("/api/provider/queue/swap-next")
    public ResponseEntity<?> providerSwapNext(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        try {
            return ResponseEntity.ok(queueService.providerSwapNext(provider.getId()));
        } catch (IllegalStateException | IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    @PostMapping("/api/provider/queue/requests/{tokenId}/accept")
    public ResponseEntity<?> providerAcceptTokenRequest(
            @org.springframework.web.bind.annotation.PathVariable("tokenId") Long tokenId,
            Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        try {
            return ResponseEntity.ok(queueService.providerAcceptTokenRequest(provider.getId(), tokenId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    @PostMapping("/api/provider/queue/requests/{tokenId}/decline")
    public ResponseEntity<?> providerDeclineTokenRequest(
            @org.springframework.web.bind.annotation.PathVariable("tokenId") Long tokenId,
            Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        try {
            return ResponseEntity.ok(queueService.providerDeclineTokenRequest(provider.getId(), tokenId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    @PostMapping("/api/provider/queue/priority-requests/{tokenId}/accept")
    public ResponseEntity<?> providerAcceptPriorityRequest(
            @org.springframework.web.bind.annotation.PathVariable("tokenId") Long tokenId,
            Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        try {
            return ResponseEntity.ok(queueService.providerAcceptPriority(provider.getId(), tokenId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    @PostMapping("/api/provider/queue/priority-requests/{tokenId}/reject")
    public ResponseEntity<?> providerRejectPriorityRequest(
            @org.springframework.web.bind.annotation.PathVariable("tokenId") Long tokenId,
            Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof Provider provider)) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized provider access"));
        }
        try {
            return ResponseEntity.ok(queueService.providerRejectPriority(provider.getId(), tokenId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }
}

