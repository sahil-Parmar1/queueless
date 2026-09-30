package com.queueless.office_service.user;

import java.util.Map;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.queueless.office_service.config.FileStorageService;

@RestController
@RequestMapping("/api/office")
public class OfficeProfileController {

    private final OfficeProfileRepository profileRepository;
    private final UserRepository userRepository;
    private final FileStorageService fileStorageService;
    private final com.queueless.office_service.provider.ProviderService providerService;

    public OfficeProfileController(
            OfficeProfileRepository profileRepository,
            UserRepository userRepository,
            FileStorageService fileStorageService,
            com.queueless.office_service.provider.ProviderService providerService) {
        this.profileRepository = profileRepository;
        this.userRepository = userRepository;
        this.fileStorageService = fileStorageService;
        this.providerService = providerService;
    }

    @GetMapping("/profile")
    public ResponseEntity<?> getOfficeProfile(Authentication authentication) {
        User user;
        if (authentication.getPrincipal() instanceof User u) {
            user = u;
        } else {
            String email = authentication.getName();
            user = userRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("User not found: " + email));
        }

        if (user.getRole() == Role.OFFICE && user.getOfficeId() == null) {
            user.setOfficeId(generateUniqueOfficeId());
            user = userRepository.save(user);
        }

        OfficeProfile profile = profileRepository.findByUserId(user.getId())
                .orElse(null);

        if (profile != null && profile.getOfficeId() == null && user.getOfficeId() != null) {
            profile.setOfficeId(user.getOfficeId());
            profile = profileRepository.save(profile);
        }

        if (profile == null) {
            return ResponseEntity.ok(Map.of(
                    "hasProfile", false,
                    "user", user,
                    "officeId", user.getOfficeId() != null ? user.getOfficeId() : ""
            ));
        }

        return ResponseEntity.ok(Map.of(
                    "hasProfile", true,
                    "user", user,
                    "profile", profile,
                    "officeId", profile.getOfficeId() != null ? profile.getOfficeId() : (user.getOfficeId() != null ? user.getOfficeId() : "")
        ));
    }

    @GetMapping("/settings/queue")
    public ResponseEntity<?> getOfficeQueueSettings(Authentication authentication) {
        User user = resolveAuthenticatedUser(authentication);
        OfficeProfile profile = profileRepository.findByUserId(user.getId())
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.NOT_FOUND, "Office profile not found"));
        return ResponseEntity.ok(providerService.getOfficeQueueSettings(profile.getId()));
    }

    @org.springframework.web.bind.annotation.PutMapping("/settings/queue")
    public ResponseEntity<?> updateOfficeQueueSettings(
            @RequestBody com.queueless.office_service.user.dto.OfficeQueueSettingsRequest request,
            Authentication authentication) {
        User user = resolveAuthenticatedUser(authentication);
        OfficeProfile profile = profileRepository.findByUserId(user.getId())
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.NOT_FOUND, "Office profile not found"));
        try {
            return ResponseEntity.ok(providerService.updateOfficeQueueSettings(profile.getId(), request));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage(), "message", e.getMessage()));
        }
    }

    private User resolveAuthenticatedUser(Authentication authentication) {
        if (authentication.getPrincipal() instanceof User u) {
            return u;
        }
        String email = authentication.getName();
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.UNAUTHORIZED, "User not found: " + email));
    }

    @PostMapping(value = "/onboarding", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> submitOnboarding(
            Authentication authentication,
            @RequestParam("category") OfficeCategory category,
            @RequestParam("phone") String phone,
            @RequestParam("address") String address,
            @RequestParam("city") String city,
            @RequestParam("state") String state,
            @RequestParam("pincode") String pincode,
            @RequestParam("openingTime") String openingTime,
            @RequestParam("closingTime") String closingTime,
            @RequestParam(value = "description", required = false) String description,

            // Clinic specific
            @RequestParam(value = "doctorName", required = false) String doctorName,
            @RequestParam(value = "specialization", required = false) String specialization,
            @RequestParam(value = "medicalRegistrationNumber", required = false) String medicalRegistrationNumber,

            // Salon specific
            @RequestParam(value = "salonType", required = false) String salonType,
            @RequestParam(value = "tradeLicenseNumber", required = false) String tradeLicenseNumber,

            // Files (Primary License + Optional ID Proof)
            @RequestParam("primaryDocument") MultipartFile primaryDocument,
            @RequestParam(value = "secondaryDocument", required = false) MultipartFile secondaryDocument
    ) {
        User user;
        if (authentication.getPrincipal() instanceof User u) {
            user = u;
        } else {
            String email = authentication.getName();
            user = userRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("User not found: " + email));
        }

        if (user.getRole() == Role.OFFICE && user.getOfficeId() == null) {
            user.setOfficeId(generateUniqueOfficeId());
            user = userRepository.save(user);
        }

        OfficeProfile profile = profileRepository.findByUserId(user.getId())
                .orElse(new OfficeProfile());

        profile.setUser(user);
        if (profile.getOfficeId() == null && user.getOfficeId() != null) {
            profile.setOfficeId(user.getOfficeId());
        }
        profile.setCategory(category);
        profile.setPhone(phone);
        profile.setAddress(address);
        profile.setCity(city);
        profile.setState(state);
        profile.setPincode(pincode);
        profile.setOpeningTime(openingTime);
        profile.setClosingTime(closingTime);
        profile.setDescription(description);

        if (category == OfficeCategory.CLINIC) {
            profile.setDoctorName(doctorName);
            profile.setSpecialization(specialization);
            profile.setMedicalRegistrationNumber(medicalRegistrationNumber);
        } else if (category == OfficeCategory.SALON) {
            profile.setSalonType(salonType);
            profile.setTradeLicenseNumber(tradeLicenseNumber);
        } else if (category == OfficeCategory.OTHER) {
            profile.setSpecialization(specialization);
            profile.setTradeLicenseNumber(tradeLicenseNumber);
        }

        // Save Primary Document
        if (primaryDocument != null && !primaryDocument.isEmpty()) {
            String fileUrl = fileStorageService.saveFile(primaryDocument);
            OfficeDocument doc = new OfficeDocument();
            doc.setOfficeProfile(profile);
            String docType = "BUSINESS_DOCUMENT";
            if (category == OfficeCategory.CLINIC) docType = "CLINIC_REGISTRATION";
            else if (category == OfficeCategory.SALON) docType = "TRADE_LICENSE";
            else if (category == OfficeCategory.OTHER) docType = "BUSINESS_REGISTRATION";
            doc.setDocumentType(docType);
            doc.setOriginalFileName(primaryDocument.getOriginalFilename());
            doc.setFileUrl(fileUrl);
            doc.setContentType(primaryDocument.getContentType());
            doc.setFileSize(primaryDocument.getSize());
            profile.getDocuments().add(doc);
        }

        // Save Secondary Document (if provided)
        if (secondaryDocument != null && !secondaryDocument.isEmpty()) {
            String fileUrl = fileStorageService.saveFile(secondaryDocument);
            OfficeDocument doc = new OfficeDocument();
            doc.setOfficeProfile(profile);
            String docType = "ID_PROOF";
            if (category == OfficeCategory.CLINIC) docType = "DOCTOR_DEGREE";
            else if (category == OfficeCategory.SALON) docType = "OWNER_ID_PROOF";
            else if (category == OfficeCategory.OTHER) docType = "OWNER_ID_PROOF";
            doc.setDocumentType(docType);
            doc.setOriginalFileName(secondaryDocument.getOriginalFilename());
            doc.setFileUrl(fileUrl);
            doc.setContentType(secondaryDocument.getContentType());
            doc.setFileSize(secondaryDocument.getSize());
            profile.getDocuments().add(doc);
        }

        OfficeProfile saved = profileRepository.save(profile);
        return ResponseEntity.ok(Map.of(
                "message", "Office details and documents submitted for verification",
                "profileId", saved.getId(),
                "status", saved.getVerificationStatus()
        ));
    }

    private String generateUniqueOfficeId() {
        String chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        java.security.SecureRandom random = new java.security.SecureRandom();
        String id;
        do {
            StringBuilder sb = new StringBuilder("OFF-");
            for (int i = 0; i < 6; i++) {
                sb.append(chars.charAt(random.nextInt(chars.length())));
            }
            id = sb.toString();
        } while (userRepository.existsByOfficeId(id) || profileRepository.existsByOfficeId(id));
        return id;
    }
}
