package com.queueless.office_service.provider;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.queueless.office_service.provider.dto.ProviderRequest;
import com.queueless.office_service.provider.dto.ProviderResponse;
import com.queueless.office_service.user.OfficeProfile;
import com.queueless.office_service.user.OfficeProfileRepository;
import com.queueless.office_service.user.User;
import com.queueless.office_service.user.UserRepository;

@RestController
@RequestMapping("/api/office/providers")
public class ProviderController {

    private final ProviderService providerService;
    private final OfficeProfileRepository officeProfileRepository;
    private final UserRepository userRepository;

    public ProviderController(
            ProviderService providerService,
            OfficeProfileRepository officeProfileRepository,
            UserRepository userRepository) {
        this.providerService = providerService;
        this.officeProfileRepository = officeProfileRepository;
        this.userRepository = userRepository;
    }

    /**
     * List all providers of the authenticated office.
     */
    @GetMapping
    public ResponseEntity<List<ProviderResponse>> getProviders(Authentication authentication) {
        OfficeProfile office = resolveAuthenticatedOffice(authentication);
        return ResponseEntity.ok(providerService.getOfficeProviders(office.getId()));
    }

    /**
     * Add a new provider for the authenticated office.
     */
    @PostMapping
    public ResponseEntity<ProviderResponse> createProvider(
            @RequestBody ProviderRequest request,
            Authentication authentication) {
        OfficeProfile office = resolveAuthenticatedOffice(authentication);
        ProviderResponse response = providerService.createProvider(office.getId(), request);
        return ResponseEntity.ok(response);
    }

    /**
     * Get details of a specific provider.
     */
    @GetMapping("/{id}")
    public ResponseEntity<ProviderResponse> getProvider(
            @PathVariable("id") Long id,
            Authentication authentication) {
        OfficeProfile office = resolveAuthenticatedOffice(authentication);
        return ResponseEntity.ok(providerService.getProviderDetails(office.getId(), id));
    }

    /**
     * Update provider details and working schedules.
     */
    @PutMapping("/{id}")
    public ResponseEntity<ProviderResponse> updateProvider(
            @PathVariable("id") Long id,
            @RequestBody ProviderRequest request,
            Authentication authentication) {
        OfficeProfile office = resolveAuthenticatedOffice(authentication);
        return ResponseEntity.ok(providerService.updateProvider(office.getId(), id, request));
    }

    /**
     * Activate or deactivate a provider.
     */
    @PatchMapping("/{id}/status")
    public ResponseEntity<ProviderResponse> updateProviderStatus(
            @PathVariable("id") Long id,
            @RequestBody(required = false) Map<String, Object> body,
            @RequestParam(value = "active", required = false) Boolean activeParam,
            Authentication authentication) {
        OfficeProfile office = resolveAuthenticatedOffice(authentication);

        boolean active = true;
        if (activeParam != null) {
            active = activeParam;
        } else if (body != null && body.containsKey("active")) {
            active = Boolean.parseBoolean(body.get("active").toString());
        }

        return ResponseEntity.ok(providerService.setProviderActiveStatus(office.getId(), id, active));
    }

    /**
     * Safely delete a provider if no active queue tokens exist.
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteProvider(
            @PathVariable("id") Long id,
            Authentication authentication) {
        OfficeProfile office = resolveAuthenticatedOffice(authentication);
        providerService.deleteProvider(office.getId(), id);
        return ResponseEntity.ok(Map.of(
                "message", "Provider deleted successfully",
                "providerId", id
        ));
    }

    private OfficeProfile resolveAuthenticatedOffice(Authentication authentication) {
        if (authentication == null) {
            throw new RuntimeException("Unauthorized: Authentication token is required");
        }

        User user;
        if (authentication.getPrincipal() instanceof User u) {
            user = u;
        } else {
            String email = authentication.getName();
            user = userRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("User not found: " + email));
        }

        return officeProfileRepository.findByUserId(user.getId())
                .orElseThrow(() -> new RuntimeException("Office profile not found for authenticated account"));
    }

    @org.springframework.web.bind.annotation.ExceptionHandler({IllegalArgumentException.class, IllegalStateException.class})
    public ResponseEntity<Map<String, String>> handleClientError(RuntimeException e) {
        return ResponseEntity.badRequest().body(Map.of(
                "error", e.getMessage(),
                "message", e.getMessage()
        ));
    }
}
