package com.queueless.customer_service.controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.queueless.customer_service.dto.ProviderResponse;
import com.queueless.customer_service.model.OfficeCategory;
import com.queueless.customer_service.model.VerificationStatus;
import com.queueless.customer_service.service.CustomerOfficeService;

@RestController
@RequestMapping("/api/offices")
public class CustomerOfficeController {

    private final CustomerOfficeService officeService;

    public CustomerOfficeController(CustomerOfficeService officeService) {
        this.officeService = officeService;
    }

    @GetMapping("/search")
    public ResponseEntity<?> searchOffices(
            @RequestParam(value = "query", required = false) String query,
            @RequestParam(value = "category", required = false) OfficeCategory category,
            @RequestParam(value = "city", required = false) String city,
            @RequestParam(value = "status", required = false) VerificationStatus status,
            @RequestParam(value = "includeAllStatus", defaultValue = "false") boolean includeAllStatus) {

        List<Map<String, Object>> result = officeService.searchOffices(query, category, city, status, includeAllStatus);
        return ResponseEntity.ok(result);
    }

    @GetMapping("/featured")
    public ResponseEntity<?> getFeaturedOffices() {
        List<Map<String, Object>> result = officeService.getFeaturedOffices();
        return ResponseEntity.ok(result);
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getOfficeDetails(@PathVariable("id") Long id) {
        try {
            Map<String, Object> details = officeService.getOfficeDetails(id);
            return ResponseEntity.ok(details);
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @GetMapping("/{id}/providers")
    public ResponseEntity<?> getOfficeProviders(@PathVariable("id") Long id) {
        List<ProviderResponse> providers = officeService.getOfficeProviders(id);
        return ResponseEntity.ok(providers);
    }
}
