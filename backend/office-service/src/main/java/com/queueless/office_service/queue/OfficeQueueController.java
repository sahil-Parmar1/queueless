package com.queueless.office_service.queue;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.queueless.office_service.user.OfficeProfile;
import com.queueless.office_service.user.OfficeProfileRepository;
import com.queueless.office_service.user.User;
import com.queueless.office_service.user.UserRepository;

@RestController
@RequestMapping("/api/office/queue")
public class OfficeQueueController {

    private final QueueService queueService;
    private final OfficeProfileRepository officeProfileRepository;
    private final UserRepository userRepository;

    public OfficeQueueController(
            QueueService queueService,
            OfficeProfileRepository officeProfileRepository,
            UserRepository userRepository) {
        this.queueService = queueService;
        this.officeProfileRepository = officeProfileRepository;
        this.userRepository = userRepository;
    }

    private OfficeProfile getAuthenticatedOffice(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }
        Long userId = null;
        if (authentication.getPrincipal() instanceof User user) {
            userId = user.getId();
        } else if (authentication.getName() != null) {
            User user = userRepository.findByEmail(authentication.getName())
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));
            userId = user.getId();
        }

        if (userId == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Cannot identify user");
        }

        return officeProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Office profile not found"));
    }

    @GetMapping("/live")
    public ResponseEntity<?> getMyOfficeLiveQueue(Authentication authentication) {
        OfficeProfile office = getAuthenticatedOffice(authentication);
        return ResponseEntity.ok(queueService.getLiveQueue(office.getId()));
    }

    @PostMapping("/call-next")
    public ResponseEntity<?> callNext(Authentication authentication) {
        OfficeProfile office = getAuthenticatedOffice(authentication);
        return ResponseEntity.ok(queueService.callNext(office.getId()));
    }

    @PostMapping("/complete")
    public ResponseEntity<?> completeCurrent(Authentication authentication) {
        OfficeProfile office = getAuthenticatedOffice(authentication);
        return ResponseEntity.ok(queueService.completeCurrent(office.getId()));
    }

    @PostMapping("/skip")
    public ResponseEntity<?> skipCurrent(Authentication authentication) {
        OfficeProfile office = getAuthenticatedOffice(authentication);
        return ResponseEntity.ok(queueService.skipCurrent(office.getId()));
    }

    @PostMapping("/tokens/{tokenId}/forward")
    public ResponseEntity<?> forwardToken(
            @PathVariable("tokenId") Long tokenId,
            @RequestBody Map<String, Object> body,
            Authentication authentication) {
        OfficeProfile office = getAuthenticatedOffice(authentication);
        if (!body.containsKey("providerId") || body.get("providerId") == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "providerId is required", "message", "Provider ID is required"));
        }
        Long providerId = Long.valueOf(body.get("providerId").toString());
        try {
            return ResponseEntity.ok(queueService.forwardTokenToProvider(office.getId(), tokenId, providerId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    @PostMapping("/tokens/{tokenId}/serve")
    public ResponseEntity<?> serveTokenAtDesk(
            @PathVariable("tokenId") Long tokenId,
            Authentication authentication) {
        OfficeProfile office = getAuthenticatedOffice(authentication);
        try {
            return ResponseEntity.ok(queueService.serveTokenAtDesk(office.getId(), tokenId));
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }
}
