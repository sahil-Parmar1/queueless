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

@RestController
public class ProviderPortalController {

    private final ProviderService providerService;

    public ProviderPortalController(ProviderService providerService) {
        this.providerService = providerService;
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
}
