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
}
