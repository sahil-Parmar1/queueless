package com.queueless.office_service.user;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.queueless.office_service.queue.QueueTokenRepository;
import com.queueless.office_service.queue.TokenStatus;

@RestController
@RequestMapping("/api/offices")
public class PublicOfficeController {

    private final OfficeProfileRepository profileRepository;
    private final QueueTokenRepository tokenRepository;

    public PublicOfficeController(
            OfficeProfileRepository profileRepository,
            QueueTokenRepository tokenRepository) {
        this.profileRepository = profileRepository;
        this.tokenRepository = tokenRepository;
    }

    /**
     * Search offices by query, category, and city.
     * By default, returns APPROVED offices, or all if no approved exist yet (for dev convenience).
     */
    @GetMapping("/search")
    public ResponseEntity<?> searchOffices(
            @RequestParam(value = "query", required = false) String query,
            @RequestParam(value = "category", required = false) OfficeCategory category,
            @RequestParam(value = "city", required = false) String city,
            @RequestParam(value = "status", required = false) VerificationStatus status,
            @RequestParam(value = "includeAllStatus", defaultValue = "false") boolean includeAllStatus) {

        VerificationStatus filterStatus = includeAllStatus ? null : (status != null ? status : VerificationStatus.APPROVED);

        List<OfficeProfile> profiles = profileRepository.searchOffices(
                (query != null && !query.isBlank()) ? query.trim() : null,
                category,
                (city != null && !city.isBlank()) ? city.trim() : null,
                filterStatus
        );

        // Dev-friendly fallback: if no approved offices found, include pending offices so users can test immediately
        if (profiles.isEmpty() && filterStatus == VerificationStatus.APPROVED) {
            profiles = profileRepository.searchOffices(
                    (query != null && !query.isBlank()) ? query.trim() : null,
                    category,
                    (city != null && !city.isBlank()) ? city.trim() : null,
                    null
            );
        }

        List<Map<String, Object>> result = new ArrayList<>();
        for (OfficeProfile p : profiles) {
            result.add(formatOfficeSummary(p));
        }

        return ResponseEntity.ok(result);
    }

    /**
     * Get public details of a single office.
     */
    @GetMapping("/{id}")
    public ResponseEntity<?> getOfficeDetails(@PathVariable("id") Long id) {
        OfficeProfile p = profileRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Office not found: " + id));

        Map<String, Object> details = formatOfficeSummary(p);
        details.put("description", p.getDescription());
        details.put("phone", p.getPhone());
        details.put("state", p.getState());
        details.put("pincode", p.getPincode());
        details.put("tradeLicenseNumber", p.getTradeLicenseNumber());
        details.put("medicalRegistrationNumber", p.getMedicalRegistrationNumber());

        return ResponseEntity.ok(details);
    }

    /**
     * Get featured / nearby active offices.
     */
    @GetMapping("/featured")
    public ResponseEntity<?> getFeaturedOffices() {
        List<OfficeProfile> profiles = profileRepository.findAll();
        List<Map<String, Object>> result = new ArrayList<>();
        for (OfficeProfile p : profiles) {
            result.add(formatOfficeSummary(p));
        }
        return ResponseEntity.ok(result);
    }

    /**
     * Get supported categories with names and display details.
     */
    @GetMapping("/categories")
    public ResponseEntity<?> getCategories() {
        List<Map<String, String>> categories = Arrays.stream(OfficeCategory.values())
                .map(cat -> Map.of(
                        "key", cat.name(),
                        "label", getCategoryLabel(cat)
                ))
                .toList();

        return ResponseEntity.ok(categories);
    }

    /**
     * Update office status (Admin / Developer tool).
     */
    @PutMapping("/{id}/status")
    public ResponseEntity<?> updateOfficeStatus(
            @PathVariable("id") Long id,
            @RequestParam("status") VerificationStatus status) {

        OfficeProfile profile = profileRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Office not found: " + id));

        profile.setVerificationStatus(status);
        OfficeProfile saved = profileRepository.save(profile);

        return ResponseEntity.ok(Map.of(
                "message", "Office verification status updated successfully",
                "officeId", saved.getId(),
                "status", saved.getVerificationStatus().name()
        ));
    }

    private Map<String, Object> formatOfficeSummary(OfficeProfile p) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", p.getId());
        map.put("name", p.getUser() != null ? p.getUser().getName() : "Office");
        map.put("email", p.getUser() != null ? p.getUser().getEmail() : "");
        map.put("category", p.getCategory() != null ? p.getCategory().name() : "OTHER");
        map.put("address", p.getAddress());
        map.put("city", p.getCity());
        map.put("openingTime", p.getOpeningTime() != null ? p.getOpeningTime() : "09:00 AM");
        map.put("closingTime", p.getClosingTime() != null ? p.getClosingTime() : "08:00 PM");
        map.put("doctorName", p.getDoctorName());
        map.put("specialization", p.getSpecialization());
        map.put("salonType", p.getSalonType());
        map.put("verificationStatus", p.getVerificationStatus().name());

        // Queue metrics
        Long waitingCount = tokenRepository.countByOfficeIdAndStatus(p.getId(), TokenStatus.WAITING);
        var activeToken = tokenRepository.findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(
                p.getId(),
                List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
        ).orElse(null);

        map.put("waitingCount", waitingCount != null ? waitingCount : 0);
        map.put("activeToken", activeToken != null ? activeToken.getTokenNumber() : null);
        map.put("estimatedWaitMinutes", (waitingCount != null ? waitingCount : 0) * 12);

        return map;
    }

    private String getCategoryLabel(OfficeCategory cat) {
        if (cat == null) return "Office";
        return switch (cat) {
            case CLINIC -> "Clinic & Hospital";
            case SALON -> "Salon & Spa";
            case BANK -> "Bank & Financial";
            case RESTAURANT -> "Restaurant & Cafe";
            case OTHER -> "Government & General Office";
            default -> "Office";
        };
    }
}
