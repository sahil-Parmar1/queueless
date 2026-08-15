package com.queueless.queueless.user;
import java.util.Map;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.queueless.queueless.config.FileStorageService;

@RestController
@RequestMapping("/api/office")
public class OfficeProfileController {

    private final OfficeProfileRepository profileRepository;
    private final UserRepository userRepository;
    private final FileStorageService fileStorageService;

    public OfficeProfileController(
            OfficeProfileRepository profileRepository,
            UserRepository userRepository,
            FileStorageService fileStorageService) {
        this.profileRepository = profileRepository;
        this.userRepository = userRepository;
        this.fileStorageService = fileStorageService;
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

        OfficeProfile profile = profileRepository.findByUserId(user.getId())
                .orElse(new OfficeProfile());

        profile.setUser(user);
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
}
