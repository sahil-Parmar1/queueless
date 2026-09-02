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

        Long officeId = Long.valueOf(body.get("officeId").toString());
        String customerName = body.get("customerName") != null ? body.get("customerName").toString() : null;
        String customerPhone = body.get("customerPhone") != null ? body.get("customerPhone").toString() : null;
        String customerEmail = body.get("customerEmail") != null ? body.get("customerEmail").toString() : null;
        Long customerId = null;

        if (authentication != null && authentication.getPrincipal() instanceof User user) {
            customerId = user.getId();
            if (customerName == null || customerName.isBlank()) customerName = user.getName();
            if (customerEmail == null || customerEmail.isBlank()) customerEmail = user.getEmail();
        } else if (authentication != null && authentication.getName() != null) {
            if (customerEmail == null || customerEmail.isBlank()) customerEmail = authentication.getName();
        }

        Map<String, Object> result = queueService.bookToken(
                officeId, customerId, customerName, customerPhone, customerEmail
        );

        return ResponseEntity.ok(result);
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
}
